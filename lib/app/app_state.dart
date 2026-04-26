import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dexcom_share_api/dexcom_share_api.dart';

import 'alarm_audio.dart';
import 'alarm_logic.dart';
import 'alarm_settings.dart';
import 'background_monitor.dart';
import 'credentials.dart';
import 'dexcom_repository.dart';
import 'prediction.dart';

enum AppPhase { initializing, loggedOut, loggedIn }

class AppState extends ChangeNotifier {
  AppState({
    required CredentialStore credentialStore,
    AlarmSettingsStore? alarmSettingsStore,
  }) : _credentialStore = credentialStore,
       _alarmSettingsStore = alarmSettingsStore ?? AlarmSettingsStore();

  final CredentialStore _credentialStore;
  final AlarmSettingsStore _alarmSettingsStore;
  final AlarmAudioPlayer _alarmAudio = AlarmAudioPlayer();

  AppPhase _phase = AppPhase.initializing;
  AppPhase get phase => _phase;

  DexcomRepository? _repo;
  StreamSubscription<GlucoseSnapshot>? _sub;

  GlucoseSnapshot? _latest;
  GlucoseSnapshot? get latest => _latest;

  List<GlucoseEntry> _history = const [];
  List<GlucoseEntry> get history => _history;

  PredictionResult? _prediction;
  PredictionResult? get prediction => _prediction;

  bool _isHistoryLoading = false;
  bool get isHistoryLoading => _isHistoryLoading;

  String? _historyError;
  String? get historyError => _historyError;

  String? _error;
  String? get error => _error;

  bool _rememberMe = true;
  bool get rememberMe => _rememberMe;

  AlarmState _alarmState = const AlarmState();

  AlarmSettings _alarmSettings = AlarmSettingsStore.defaults;
  AlarmSettings get alarmSettings => _alarmSettings;

  String _username = '';
  String get username => _username;

  Future<void> init() async {
    _alarmSettings = await _alarmSettingsStore.read();
    final saved = await _credentialStore.read();
    if (saved != null) {
      _rememberMe = saved.rememberMe;
      _username = saved.username;
      await login(
        username: saved.username,
        password: saved.password,
        rememberMe: saved.rememberMe,
        server: saved.server,
      );
      return;
    }
    _phase = AppPhase.loggedOut;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
    required bool rememberMe,
    String? server,
  }) async {
    _error = null;
    _rememberMe = rememberMe;
    _username = username;
    _phase = AppPhase.initializing;
    notifyListeners();

    await _disposeRepo();
    final repo = DexcomShareRepository(
      username: username,
      password: password,
      server: server ?? _alarmSettings.server.storageValue,
    );
    _repo = repo;

    try {
      // Validate credentials by fetching once.
      final first = await repo.refreshOnce();
      _latest = first;
      _phase = AppPhase.loggedIn;
      notifyListeners();

      unawaited(_refreshHistory());

      if (rememberMe) {
        await _credentialStore.write(
          SavedCredentials(
            username: username,
            password: password,
            rememberMe: rememberMe,
            server: server ?? _alarmSettings.server.storageValue,
          ),
        );
        await BackgroundMonitor.setUserPaused(false);
        unawaited(BackgroundMonitor.tryAutoStartIfEligible());
      } else {
        await _credentialStore.write(
          SavedCredentials(
            username: '',
            password: '',
            rememberMe: rememberMe,
            server: server ?? _alarmSettings.server.storageValue,
          ),
        );
        unawaited(BackgroundMonitor.stop());
      }

      _sub = repo.watchLatest().listen(
        _handleSnapshot,
        onError: (Object e) {
          _error = _describeError(e);
          notifyListeners();
        },
      );

      _handleSnapshot(first);
    } catch (e) {
      _error = _describeError(e);
      _phase = AppPhase.loggedOut;
      notifyListeners();
      await _disposeRepo();
    }
  }

  Future<void> logout({bool clearSaved = false}) async {
    _error = null;
    _latest = null;
    _history = const [];
    _prediction = null;
    _alarmState = const AlarmState();
    unawaited(BackgroundMonitor.stop());
    if (clearSaved) {
      await _credentialStore.clear();
    }
    await _alarmAudio.stop();
    await _disposeRepo();
    _phase = AppPhase.loggedOut;
    notifyListeners();
  }

  Future<void> updateAlarmSettings(AlarmSettings next) async {
    _alarmSettings = next;
    _updatePredictionFromHistory();
    await _alarmSettingsStore.write(next);
    notifyListeners();
  }

  Future<void> refreshNow() async {
    final repo = _repo;
    if (repo == null) return;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await repo.refreshOnce();
      _handleSnapshot(snapshot);
      unawaited(_refreshHistory());
    } catch (e) {
      _error = _describeError(e);
      notifyListeners();
    }
  }

  Future<void> _refreshHistory() async {
    final repo = _repo;
    if (repo == null) return;
    _isHistoryLoading = true;
    _historyError = null;
    notifyListeners();
    try {
      final list = await repo.fetchHistory(minutes: 24 * 60, maxCount: 288);
      // Dexcom returns newest-first; UI wants oldest-first.
      final ordered = list
          .toList(growable: false)
          .reversed
          .toList(growable: false);
      _history = ordered;
      _prediction = predictNext20Minutes(
        historyOldestFirst: _history,
        algorithm: _alarmSettings.predictionAlgorithm,
        nowUtc: DateTime.now().toUtc(),
      );
    } catch (e) {
      _historyError = _describeError(e);
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshHistory() => _refreshHistory();

  Future<void> testAlarm() async {
    if (!_alarmSettings.enabled) return;
    await _alarmAudio.playAlarm();
  }

  void _handleSnapshot(GlucoseSnapshot snapshot) {
    final previousTimestamp = _latest?.entry.timestamp;
    _latest = snapshot;
    _error = null;
    _mergeHistory(snapshot.entry);
    _updatePredictionFromHistory();
    notifyListeners();
    if (previousTimestamp != null &&
        previousTimestamp != snapshot.entry.timestamp) {
      unawaited(_refreshHistory());
    }

    final now = DateTime.now().toUtc();
    final readingTimeUtc = DateTime.tryParse(snapshot.entry.timestamp);
    final staleAfter = Duration(minutes: _alarmSettings.staleAfterMinutes);
    final isStale = readingTimeUtc == null
        ? false
        : isDataStale(
            now: now,
            readingTimeUtc: readingTimeUtc,
            staleAfter: staleAfter,
          );

    final nowLocal = DateTime.now();
    final critical = evaluateCriticalLowAlarm(
      state: _alarmState,
      mmol: snapshot.entry.mmol,
      timestampIsoUtc: snapshot.entry.timestamp,
      now: nowLocal,
    );
    if (critical.shouldTrigger) {
      _alarmState = _alarmState.copyWith(
        lastCriticalLowAlarmAt: nowLocal,
        lastAlarmedTimestampIsoUtc: snapshot.entry.timestamp,
        lastAlarmedAt: nowLocal,
      );
      notifyListeners();
      unawaited(_alarmAudio.playPanicAlarm());
      return;
    }

    final predictedPoints = _prediction?.nextPoints;
    final predictedMmol = predictedPoints == null || predictedPoints.isEmpty
        ? null
        : predictedPoints.last.mmol;
    final predictedLow = evaluatePredictedLowAlarm(
      state: _alarmState,
      predictedMmol: predictedMmol,
      timestampIsoUtc: snapshot.entry.timestamp,
      now: nowLocal,
      predictionCanAlarm: _prediction?.quality.canAlarm ?? false,
      isEnabled: _alarmSettings.predictionAlarmEnabled,
      thresholdMmol: _alarmSettings.predictionAlarmMmol,
    );
    if (predictedLow.shouldTrigger) {
      _alarmState = _alarmState.copyWith(
        lastPredictedLowAlarmAt: nowLocal,
        lastAlarmedTimestampIsoUtc: snapshot.entry.timestamp,
        lastAlarmedAt: nowLocal,
      );
      notifyListeners();
      unawaited(_alarmAudio.playPredictedLowAlarm());
      return;
    }

    final policy = AlarmPolicy(
      minMmol: _alarmSettings.minMmol,
      maxMmol: _alarmSettings.maxMmol,
      minRepeatInterval: const Duration(minutes: 1),
    );
    final decision = evaluateAlarm(
      policy: policy,
      state: _alarmState,
      mmol: snapshot.entry.mmol,
      timestampIsoUtc: snapshot.entry.timestamp,
      now: nowLocal,
      isEnabled: _alarmSettings.enabled,
    );
    final noDataDecision = evaluateNoDataAlarm(
      state: _alarmState,
      now: nowLocal,
      isNoData: _alarmSettings.staleAlarmEnabled && isStale,
    );

    final shouldAlarm = decision.shouldTrigger || noDataDecision.shouldTrigger;

    if (shouldAlarm) {
      _alarmState = _alarmState.copyWith(
        lastAlarmedTimestampIsoUtc: snapshot.entry.timestamp,
        lastAlarmedAt: nowLocal,
      );
      notifyListeners();
      unawaited(_alarmAudio.playAlarm());
    }
  }

  void _mergeHistory(GlucoseEntry entry) {
    // Keep the chart/prediction updating without re-fetching full history
    // each poll. Dexcom can send repeats; we dedupe by timestamp.
    final hist = _history;
    if (hist.isEmpty) {
      _history = [entry];
      return;
    }

    final last = hist.last;
    if (last.timestamp == entry.timestamp) {
      // Replace last to keep any corrected values.
      final next = hist.toList(growable: true);
      next[next.length - 1] = entry;
      _history = next;
      return;
    }

    // Only append if this is newer than the last known reading.
    final lastTime = DateTime.tryParse(last.timestamp);
    final newTime = DateTime.tryParse(entry.timestamp);
    if (lastTime != null && newTime != null && !newTime.isAfter(lastTime)) {
      return;
    }

    final next = hist.toList(growable: true)..add(entry);
    // Keep bounded (matches fetchHistory maxCount).
    if (next.length > 288) {
      next.removeRange(0, next.length - 288);
    }
    _history = next;
  }

  void _updatePredictionFromHistory() {
    final hist = _history;
    if (hist.length < 3) {
      _prediction = null;
      return;
    }
    _prediction = predictNext20Minutes(
      historyOldestFirst: hist,
      algorithm: _alarmSettings.predictionAlgorithm,
      nowUtc: DateTime.now().toUtc(),
    );
  }

  Future<void> _disposeRepo() async {
    await _sub?.cancel();
    _sub = null;
    final repo = _repo;
    _repo = null;
    if (repo != null) {
      await repo.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_alarmAudio.close());
    unawaited(_disposeRepo());
    super.dispose();
  }
}

String _describeError(Object error) {
  final message = error.toString();
  if (message.contains('timed out')) {
    return 'Dexcom did not respond in time. Check connectivity and try again.';
  }
  if (message.contains('status: 401') || message.contains('status: 403')) {
    return 'Dexcom rejected the sign-in. Check the username, password, and selected server.';
  }
  if (message.contains('SocketException') ||
      message.contains('Connection refused') ||
      message.contains('Failed host lookup')) {
    return 'Network error while contacting Dexcom. Check internet connectivity.';
  }
  if (message.contains('Dexcom returned no glucose entries')) {
    return 'Dexcom returned no recent glucose readings.';
  }
  return message;
}
