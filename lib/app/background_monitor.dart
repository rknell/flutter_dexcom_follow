import 'dart:async';

import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_audio.dart';
import 'alarm_logic.dart'
    show AlarmState, evaluatePredictedLowAlarm, isDataStale, kCriticalLowMmol;
import 'alarm_settings.dart';
import 'credentials.dart';
import 'glucose_format.dart';
import 'prediction.dart';

/// Unicode arrows for notification text (matches app trend semantics; no icon font in notifications).
String trendArrowForNotification(Trend trend) => switch (trend) {
  Trend.doubleup => '↑↑',
  Trend.singleup => '↑',
  Trend.fortyfiveup => '↗',
  Trend.flat => '→',
  Trend.fortyfivedown => '↘',
  Trend.singledown => '↓',
  Trend.doubledown => '↓↓',
};

String predictionTextForNotification(
  PredictionResult? prediction, {
  GlucoseUnit unit = GlucoseUnit.mmol,
}) {
  final points = prediction?.nextPoints;
  if (points == null || points.isEmpty) {
    return '20-min prediction unavailable';
  }
  return 'Predicted ${formatGlucoseMmol(points.last.mmol, unit)} ${unit.displayName} in 20 min';
}

String predictedLowTextForNotification(
  double predictedMmol, {
  GlucoseUnit unit = GlucoseUnit.mmol,
}) {
  return 'Predicted ${formatGlucoseMmol(predictedMmol, unit)} ${unit.displayName} in 20 min - predicted low alert';
}

class BackgroundMonitor {
  static const _channelId = 'dexcom_alarm';
  static const _channelName = 'Dexcom alarms';
  static const _channelDesc =
      'Alarms for out-of-range or stale Dexcom readings';
  static const _kUserPausedKey = 'dexcom.background_monitor_user_paused';

  /// When true, the user turned monitoring off in settings; do not auto-start until they turn it on again or signs in again.
  static Future<bool> isUserPaused() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kUserPausedKey) ?? false;
  }

  static Future<void> setUserPaused(bool paused) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUserPausedKey, paused);
  }

  /// Starts the Android foreground service if credentials are saved and the user has not paused monitoring.
  static Future<void> tryAutoStartIfEligible() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (await isUserPaused()) return;
    final creds = await CredentialStore().read();
    if (creds == null) return;
    await ensureInitialized();
    final result = await start();
    if (result is ServiceRequestFailure) {
      debugPrint('BackgroundMonitor.tryAutoStartIfEligible: ${result.error}');
    }
  }

  static Future<void> ensureInitialized() async {
    // Local notifications init
    final notifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(
      const InitializationSettings(android: androidInit),
    );

    final android = notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
        ),
      );
    }

    // Foreground service init
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'dexcom_monitor',
        channelName: 'Dexcom monitoring',
        channelDescription: 'Background Dexcom polling',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<ServiceRequestResult> start() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      var permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        permission =
            await FlutterForegroundTask.requestNotificationPermission();
      }
      if (permission != NotificationPermission.granted) {
        return ServiceRequestFailure(
          error: StateError(
            'Notification permission is required to show the monitoring notification on Android 13+.',
          ),
        );
      }
    }
    return FlutterForegroundTask.startService(
      notificationTitle: 'Dexcom monitoring',
      notificationText: 'Fetching glucose…',
      callback: startCallback,
    );
  }

  static Future<ServiceRequestResult> stop() =>
      FlutterForegroundTask.stopService();

  static Future<bool> isRunning() => FlutterForegroundTask.isRunningService;
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(DexcomTaskHandler());
}

class DexcomTaskHandler extends TaskHandler {
  DexcomClient? _client;

  /// Android 14+ swipe-dismiss; skip routine glucose FGS updates until a new Dexcom reading arrives.
  bool _foregroundGlucoseNotificationDismissed = false;

  /// Timestamp of the last reading shown on the FGS notification (Dexcom `latest.timestamp`).
  String? _lastForegroundReadingTimestamp;
  DateTime? _nextProbeNotBefore;

  final _creds = CredentialStore();
  final _settingsStore = AlarmSettingsStore();
  final _notifications = FlutterLocalNotificationsPlugin();
  final _alarmAudio = AlarmAudioPlayer();
  AlarmState _alarmState = const AlarmState();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await BackgroundMonitor.ensureInitialized();
    await _ensureClient();
    unawaited(_tick());
  }

  Future<void> _ensureClient() async {
    final saved = await _creds.read();
    if (saved == null) return;
    _client ??= DexcomClient(
      username: saved.username,
      password: saved.password,
      server: saved.server,
    );
  }

  Future<void> _updateForegroundNotification({
    required String title,
    required String text,
  }) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  Future<void> _tick() async {
    try {
      await _ensureClient();
      final client = _client;
      if (client == null) {
        await _updateForegroundNotification(
          title: 'Dexcom monitoring',
          text: 'Open the app and sign in to load glucose',
        );
        return;
      }

      final nowUtc = DateTime.now().toUtc();
      final nextProbe = _nextProbeNotBefore;
      if (nextProbe != null && nowUtc.isBefore(nextProbe)) {
        return;
      }

      final list = await client.getEstimatedGlucoseValues(
        const LatestGlucoseOptions(maxCount: 8, minutes: 1440),
      );
      if (list.isEmpty) {
        await _updateForegroundNotification(
          title: 'Dexcom monitoring',
          text: 'No readings yet — retry in 5 min',
        );
        return;
      }
      final settings = await _settingsStore.read();
      final latest = list.first;
      _scheduleNextProbe(latest);
      final historyOldestFirst = list.reversed.toList(growable: false);
      final prediction = predictNext20Minutes(
        historyOldestFirst: historyOldestFirst,
        algorithm: settings.predictionAlgorithm,
        nowUtc: DateTime.now().toUtc(),
      );
      final readingTs = latest.timestamp;
      final newDexcomReading = readingTs != _lastForegroundReadingTimestamp;
      if (!_foregroundGlucoseNotificationDismissed || newDexcomReading) {
        await _syncForegroundNotification(
          latest: latest,
          prediction: prediction,
          unit: settings.glucoseUnit,
        );
        _lastForegroundReadingTimestamp = readingTs;
        if (newDexcomReading) {
          _foregroundGlucoseNotificationDismissed = false;
        }
      }

      final criticalLow = latest.mmol <= kCriticalLowMmol;
      final predictionPoints = prediction?.nextPoints;
      final predictedMmol = predictionPoints == null || predictionPoints.isEmpty
          ? null
          : predictionPoints.last.mmol;
      final predictedLow = evaluatePredictedLowAlarm(
        state: _alarmState,
        predictedMmol: predictedMmol,
        now: nowUtc,
        predictionCanAlarm: prediction?.quality.canAlarm ?? false,
        isEnabled: settings.predictionAlarmEnabled,
        thresholdMmol: settings.predictionAlarmMmol,
      );
      if (!settings.enabled &&
          !settings.staleAlarmEnabled &&
          !criticalLow &&
          !predictedLow.shouldTrigger) {
        return;
      }

      final readingUtc = DateTime.tryParse(latest.timestamp);
      final stale = (settings.staleAlarmEnabled && readingUtc != null)
          ? isDataStale(
              now: nowUtc,
              readingTimeUtc: readingUtc,
              staleAfter: Duration(minutes: settings.staleAfterMinutes),
            )
          : false;

      final outOfRange =
          settings.enabled &&
          (latest.mmol <= settings.minMmol || latest.mmol >= settings.maxMmol);

      if (criticalLow || predictedLow.shouldTrigger || stale || outOfRange) {
        final String title;
        final String body;
        final int notifId;
        final arrow = trendArrowForNotification(latest.trend);
        if (criticalLow) {
          notifId = 2002;
          title = 'CRITICAL LOW glucose';
          body =
              '${formatGlucoseEntry(latest, settings.glucoseUnit)} ${settings.glucoseUnit.displayName} $arrow - treat hypoglycaemia urgently';
        } else if (predictedLow.shouldTrigger && predictedMmol != null) {
          notifId = 2003;
          title = 'Predicted low glucose';
          body =
              '${formatGlucoseEntry(latest, settings.glucoseUnit)} ${settings.glucoseUnit.displayName} $arrow now. ${predictedLowTextForNotification(predictedMmol, unit: settings.glucoseUnit)}';
          _alarmState = _alarmState.copyWith(
            lastPredictedLowAlarmAt: nowUtc,
            lastAlarmedTimestampIsoUtc: latest.timestamp,
            lastAlarmedAt: nowUtc,
          );
          unawaited(_alarmAudio.playPredictedLowAlarm());
        } else if (stale) {
          notifId = 2001;
          title = 'Dexcom out of sync';
          body = 'No new reading for >${settings.staleAfterMinutes} minutes';
        } else {
          notifId = 2001;
          title = 'Glucose alarm';
          body =
              '${formatGlucoseEntry(latest, settings.glucoseUnit)} ${settings.glucoseUnit.displayName} $arrow';
        }
        final playNotificationSound =
            !(predictedLow.shouldTrigger &&
                !criticalLow &&
                predictedMmol != null);
        await _notifications.show(
          notifId,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              BackgroundMonitor._channelId,
              BackgroundMonitor._channelName,
              importance: Importance.max,
              priority: Priority.max,
              playSound: playNotificationSound,
              enableVibration: true,
              category: AndroidNotificationCategory.alarm,
              fullScreenIntent: true,
            ),
          ),
        );
      }
    } catch (e) {
      // Avoid crashing the service; keep trying next tick.
      debugPrint('Background tick error: $e');
    }
  }

  Future<void> _syncForegroundNotification({
    required GlucoseEntry latest,
    required PredictionResult? prediction,
    GlucoseUnit unit = GlucoseUnit.mmol,
  }) async {
    final arrow = trendArrowForNotification(latest.trend);
    final title =
        '${formatGlucoseEntry(latest, unit)} ${unit.displayName} $arrow';
    final subtitle = predictionTextForNotification(prediction, unit: unit);
    await _updateForegroundNotification(title: title, text: subtitle);
  }

  void _scheduleNextProbe(GlucoseEntry latest) {
    final nowUtc = DateTime.now().toUtc();
    final readingUtc = DateTime.tryParse(latest.timestamp)?.toUtc();
    if (readingUtc == null) {
      _nextProbeNotBefore = nowUtc.add(const Duration(seconds: 30));
      return;
    }

    final isNewReading = latest.timestamp != _lastForegroundReadingTimestamp;
    if (isNewReading) {
      final nextUsefulProbe = readingUtc.add(const Duration(minutes: 5));
      _nextProbeNotBefore = nextUsefulProbe.isAfter(nowUtc)
          ? nextUsefulProbe
          : nowUtc.add(const Duration(seconds: 30));
    } else {
      _nextProbeNotBefore = nowUtc.add(const Duration(seconds: 30));
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Some OEMs prefer the plugin's scheduler; keep in sync.
    unawaited(_tick());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _client?.close();
    _client = null;
    await _alarmAudio.close();
  }

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {
    // Next polls skip FGS refresh until Dexcom returns a new reading timestamp.
    _foregroundGlucoseNotificationDismissed = true;
  }
}
