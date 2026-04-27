import 'package:shared_preferences/shared_preferences.dart';

import 'prediction.dart';

enum GlucoseUnit { mmol, mgdl }

extension GlucoseUnitLabel on GlucoseUnit {
  String get storageValue => switch (this) {
    GlucoseUnit.mmol => 'mmol',
    GlucoseUnit.mgdl => 'mgdl',
  };

  String get displayName => switch (this) {
    GlucoseUnit.mmol => 'mmol/L',
    GlucoseUnit.mgdl => 'mg/dL',
  };

  static GlucoseUnit fromStorageValue(String? value) {
    return GlucoseUnit.values.firstWhere(
      (v) => v.storageValue == value,
      orElse: () => GlucoseUnit.mmol,
    );
  }
}

enum DexcomShareServer { eu, us }

extension DexcomShareServerLabel on DexcomShareServer {
  String get storageValue => switch (this) {
    DexcomShareServer.eu => 'eu',
    DexcomShareServer.us => 'us',
  };

  String get displayName => switch (this) {
    DexcomShareServer.eu => 'EU/International',
    DexcomShareServer.us => 'US',
  };

  static DexcomShareServer fromStorageValue(String? value) {
    return DexcomShareServer.values.firstWhere(
      (v) => v.storageValue == value,
      orElse: () => DexcomShareServer.eu,
    );
  }
}

class AlarmSettings {
  final bool enabled;
  final DateTime? resumeEnabledAt;
  final double minMmol;
  final double maxMmol;
  final bool staleAlarmEnabled;
  final DateTime? resumeStaleAlarmAt;
  final int staleAfterMinutes;
  final PredictionAlgorithm predictionAlgorithm;
  final bool predictionAlarmEnabled;
  final DateTime? resumePredictionAlarmAt;
  final double predictionAlarmMmol;
  final GlucoseUnit glucoseUnit;
  final double idealMinMmol;
  final double idealMaxMmol;
  final DexcomShareServer server;

  const AlarmSettings({
    required this.enabled,
    required this.resumeEnabledAt,
    required this.minMmol,
    required this.maxMmol,
    required this.staleAlarmEnabled,
    required this.resumeStaleAlarmAt,
    required this.staleAfterMinutes,
    required this.predictionAlgorithm,
    required this.predictionAlarmEnabled,
    required this.resumePredictionAlarmAt,
    required this.predictionAlarmMmol,
    required this.glucoseUnit,
    required this.idealMinMmol,
    required this.idealMaxMmol,
    required this.server,
  });

  AlarmSettings copyWith({
    bool? enabled,
    Object? resumeEnabledAt = _unset,
    double? minMmol,
    double? maxMmol,
    bool? staleAlarmEnabled,
    Object? resumeStaleAlarmAt = _unset,
    int? staleAfterMinutes,
    PredictionAlgorithm? predictionAlgorithm,
    bool? predictionAlarmEnabled,
    Object? resumePredictionAlarmAt = _unset,
    double? predictionAlarmMmol,
    GlucoseUnit? glucoseUnit,
    double? idealMinMmol,
    double? idealMaxMmol,
    DexcomShareServer? server,
  }) {
    return AlarmSettings(
      enabled: enabled ?? this.enabled,
      resumeEnabledAt: resumeEnabledAt == _unset
          ? this.resumeEnabledAt
          : resumeEnabledAt as DateTime?,
      minMmol: minMmol ?? this.minMmol,
      maxMmol: maxMmol ?? this.maxMmol,
      staleAlarmEnabled: staleAlarmEnabled ?? this.staleAlarmEnabled,
      resumeStaleAlarmAt: resumeStaleAlarmAt == _unset
          ? this.resumeStaleAlarmAt
          : resumeStaleAlarmAt as DateTime?,
      staleAfterMinutes: staleAfterMinutes ?? this.staleAfterMinutes,
      predictionAlgorithm: predictionAlgorithm ?? this.predictionAlgorithm,
      predictionAlarmEnabled:
          predictionAlarmEnabled ?? this.predictionAlarmEnabled,
      resumePredictionAlarmAt: resumePredictionAlarmAt == _unset
          ? this.resumePredictionAlarmAt
          : resumePredictionAlarmAt as DateTime?,
      predictionAlarmMmol: predictionAlarmMmol ?? this.predictionAlarmMmol,
      glucoseUnit: glucoseUnit ?? this.glucoseUnit,
      idealMinMmol: idealMinMmol ?? this.idealMinMmol,
      idealMaxMmol: idealMaxMmol ?? this.idealMaxMmol,
      server: server ?? this.server,
    );
  }
}

const Object _unset = Object();

class AlarmSettingsStore {
  static const _kEnabled = 'alarm.enabled';
  static const _kResumeEnabledAt = 'alarm.resumeEnabledAt';
  static const _kMin = 'alarm.minMmol';
  static const _kMax = 'alarm.maxMmol';
  static const _kStaleEnabled = 'alarm.stale.enabled';
  static const _kResumeStaleAlarmAt = 'alarm.stale.resumeEnabledAt';
  static const _kStaleAfterMinutes = 'alarm.stale.afterMinutes';
  static const _kPredictionAlgorithm = 'prediction.algorithm';
  static const _kPredictionAlarmEnabled = 'prediction.alarm.enabled';
  static const _kResumePredictionAlarmAt = 'prediction.alarm.resumeEnabledAt';
  static const _kPredictionAlarmMmol = 'prediction.alarm.mmol';
  static const _kGlucoseUnit = 'display.glucoseUnit';
  static const _kIdealMin = 'display.idealMinMmol';
  static const _kIdealMax = 'display.idealMaxMmol';
  static const _kServer = 'dexcom.server';

  static const AlarmSettings defaults = AlarmSettings(
    enabled: true,
    resumeEnabledAt: null,
    minMmol: 3.9,
    maxMmol: 14.0,
    staleAlarmEnabled: true,
    resumeStaleAlarmAt: null,
    staleAfterMinutes: 15,
    predictionAlgorithm: PredictionAlgorithm.weightedLinearRegression,
    predictionAlarmEnabled: true,
    resumePredictionAlarmAt: null,
    predictionAlarmMmol: 3.05,
    glucoseUnit: GlucoseUnit.mmol,
    idealMinMmol: 4.0,
    idealMaxMmol: 10.0,
    server: DexcomShareServer.eu,
  );

  Future<AlarmSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    var enabled = prefs.getBool(_kEnabled) ?? defaults.enabled;
    var resumeEnabledAt = _readDateTime(prefs, _kResumeEnabledAt);
    final min = prefs.getDouble(_kMin) ?? defaults.minMmol;
    final max = prefs.getDouble(_kMax) ?? defaults.maxMmol;
    var staleEnabled =
        prefs.getBool(_kStaleEnabled) ?? defaults.staleAlarmEnabled;
    var resumeStaleAlarmAt = _readDateTime(prefs, _kResumeStaleAlarmAt);
    final staleAfter =
        prefs.getInt(_kStaleAfterMinutes) ?? defaults.staleAfterMinutes;
    final predictionAlgorithm = PredictionAlgorithmLabel.fromStorageValue(
      prefs.getString(_kPredictionAlgorithm),
    );
    var predictionAlarmEnabled =
        prefs.getBool(_kPredictionAlarmEnabled) ??
        defaults.predictionAlarmEnabled;
    var resumePredictionAlarmAt = _readDateTime(
      prefs,
      _kResumePredictionAlarmAt,
    );
    final predictionAlarmMmol =
        prefs.getDouble(_kPredictionAlarmMmol) ?? defaults.predictionAlarmMmol;
    final glucoseUnit = GlucoseUnitLabel.fromStorageValue(
      prefs.getString(_kGlucoseUnit),
    );
    final rawIdealMin = prefs.getDouble(_kIdealMin) ?? defaults.idealMinMmol;
    final rawIdealMax = prefs.getDouble(_kIdealMax) ?? defaults.idealMaxMmol;
    final idealMin = rawIdealMin.clamp(1.5, 24.9).toDouble();
    final idealMax = rawIdealMax.clamp(idealMin + 0.1, 25.0).toDouble();
    final server = DexcomShareServerLabel.fromStorageValue(
      prefs.getString(_kServer),
    );
    if (!enabled &&
        resumeEnabledAt != null &&
        !resumeEnabledAt.isAfter(now)) {
      enabled = true;
      resumeEnabledAt = null;
      await prefs.setBool(_kEnabled, true);
      await prefs.remove(_kResumeEnabledAt);
    }
    if (!staleEnabled &&
        resumeStaleAlarmAt != null &&
        !resumeStaleAlarmAt.isAfter(now)) {
      staleEnabled = true;
      resumeStaleAlarmAt = null;
      await prefs.setBool(_kStaleEnabled, true);
      await prefs.remove(_kResumeStaleAlarmAt);
    }
    if (!predictionAlarmEnabled &&
        resumePredictionAlarmAt != null &&
        !resumePredictionAlarmAt.isAfter(now)) {
      predictionAlarmEnabled = true;
      resumePredictionAlarmAt = null;
      await prefs.setBool(_kPredictionAlarmEnabled, true);
      await prefs.remove(_kResumePredictionAlarmAt);
    }
    return AlarmSettings(
      enabled: enabled,
      resumeEnabledAt: enabled ? null : resumeEnabledAt,
      minMmol: min,
      maxMmol: max,
      staleAlarmEnabled: staleEnabled,
      resumeStaleAlarmAt: staleEnabled ? null : resumeStaleAlarmAt,
      staleAfterMinutes: staleAfter,
      predictionAlgorithm: predictionAlgorithm,
      predictionAlarmEnabled: predictionAlarmEnabled,
      resumePredictionAlarmAt: predictionAlarmEnabled
          ? null
          : resumePredictionAlarmAt,
      predictionAlarmMmol: predictionAlarmMmol.clamp(1.5, min).toDouble(),
      glucoseUnit: glucoseUnit,
      idealMinMmol: idealMin,
      idealMaxMmol: idealMax,
      server: server,
    );
  }

  Future<void> write(AlarmSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, s.enabled);
    await _writeDateTime(prefs, _kResumeEnabledAt, s.resumeEnabledAt);
    await prefs.setDouble(_kMin, s.minMmol);
    await prefs.setDouble(_kMax, s.maxMmol);
    await prefs.setBool(_kStaleEnabled, s.staleAlarmEnabled);
    await _writeDateTime(prefs, _kResumeStaleAlarmAt, s.resumeStaleAlarmAt);
    await prefs.setInt(_kStaleAfterMinutes, s.staleAfterMinutes);
    await prefs.setString(
      _kPredictionAlgorithm,
      s.predictionAlgorithm.storageValue,
    );
    await prefs.setBool(_kPredictionAlarmEnabled, s.predictionAlarmEnabled);
    await _writeDateTime(
      prefs,
      _kResumePredictionAlarmAt,
      s.resumePredictionAlarmAt,
    );
    await prefs.setDouble(_kPredictionAlarmMmol, s.predictionAlarmMmol);
    await prefs.setString(_kGlucoseUnit, s.glucoseUnit.storageValue);
    await prefs.setDouble(_kIdealMin, s.idealMinMmol);
    await prefs.setDouble(_kIdealMax, s.idealMaxMmol);
    await prefs.setString(_kServer, s.server.storageValue);
  }

  DateTime? _readDateTime(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _writeDateTime(
    SharedPreferences prefs,
    String key,
    DateTime? value,
  ) {
    if (value == null) return prefs.remove(key);
    return prefs.setString(key, value.toIso8601String());
  }
}
