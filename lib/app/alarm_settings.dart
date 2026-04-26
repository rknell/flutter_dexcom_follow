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
  final double minMmol;
  final double maxMmol;
  final bool staleAlarmEnabled;
  final int staleAfterMinutes;
  final PredictionAlgorithm predictionAlgorithm;
  final bool predictionAlarmEnabled;
  final double predictionAlarmMmol;
  final GlucoseUnit glucoseUnit;
  final DexcomShareServer server;

  const AlarmSettings({
    required this.enabled,
    required this.minMmol,
    required this.maxMmol,
    required this.staleAlarmEnabled,
    required this.staleAfterMinutes,
    required this.predictionAlgorithm,
    required this.predictionAlarmEnabled,
    required this.predictionAlarmMmol,
    required this.glucoseUnit,
    required this.server,
  });

  AlarmSettings copyWith({
    bool? enabled,
    double? minMmol,
    double? maxMmol,
    bool? staleAlarmEnabled,
    int? staleAfterMinutes,
    PredictionAlgorithm? predictionAlgorithm,
    bool? predictionAlarmEnabled,
    double? predictionAlarmMmol,
    GlucoseUnit? glucoseUnit,
    DexcomShareServer? server,
  }) {
    return AlarmSettings(
      enabled: enabled ?? this.enabled,
      minMmol: minMmol ?? this.minMmol,
      maxMmol: maxMmol ?? this.maxMmol,
      staleAlarmEnabled: staleAlarmEnabled ?? this.staleAlarmEnabled,
      staleAfterMinutes: staleAfterMinutes ?? this.staleAfterMinutes,
      predictionAlgorithm: predictionAlgorithm ?? this.predictionAlgorithm,
      predictionAlarmEnabled:
          predictionAlarmEnabled ?? this.predictionAlarmEnabled,
      predictionAlarmMmol: predictionAlarmMmol ?? this.predictionAlarmMmol,
      glucoseUnit: glucoseUnit ?? this.glucoseUnit,
      server: server ?? this.server,
    );
  }
}

class AlarmSettingsStore {
  static const _kEnabled = 'alarm.enabled';
  static const _kMin = 'alarm.minMmol';
  static const _kMax = 'alarm.maxMmol';
  static const _kStaleEnabled = 'alarm.stale.enabled';
  static const _kStaleAfterMinutes = 'alarm.stale.afterMinutes';
  static const _kPredictionAlgorithm = 'prediction.algorithm';
  static const _kPredictionAlarmEnabled = 'prediction.alarm.enabled';
  static const _kPredictionAlarmMmol = 'prediction.alarm.mmol';
  static const _kGlucoseUnit = 'display.glucoseUnit';
  static const _kServer = 'dexcom.server';

  static const AlarmSettings defaults = AlarmSettings(
    enabled: true,
    minMmol: 3.9,
    maxMmol: 14.0,
    staleAlarmEnabled: true,
    staleAfterMinutes: 15,
    predictionAlgorithm: PredictionAlgorithm.weightedLinearRegression,
    predictionAlarmEnabled: true,
    predictionAlarmMmol: 3.05,
    glucoseUnit: GlucoseUnit.mmol,
    server: DexcomShareServer.eu,
  );

  Future<AlarmSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabled) ?? defaults.enabled;
    final min = prefs.getDouble(_kMin) ?? defaults.minMmol;
    final max = prefs.getDouble(_kMax) ?? defaults.maxMmol;
    final staleEnabled =
        prefs.getBool(_kStaleEnabled) ?? defaults.staleAlarmEnabled;
    final staleAfter =
        prefs.getInt(_kStaleAfterMinutes) ?? defaults.staleAfterMinutes;
    final predictionAlgorithm = PredictionAlgorithmLabel.fromStorageValue(
      prefs.getString(_kPredictionAlgorithm),
    );
    final predictionAlarmEnabled =
        prefs.getBool(_kPredictionAlarmEnabled) ??
        defaults.predictionAlarmEnabled;
    final predictionAlarmMmol =
        prefs.getDouble(_kPredictionAlarmMmol) ?? defaults.predictionAlarmMmol;
    final glucoseUnit = GlucoseUnitLabel.fromStorageValue(
      prefs.getString(_kGlucoseUnit),
    );
    final server = DexcomShareServerLabel.fromStorageValue(
      prefs.getString(_kServer),
    );
    return AlarmSettings(
      enabled: enabled,
      minMmol: min,
      maxMmol: max,
      staleAlarmEnabled: staleEnabled,
      staleAfterMinutes: staleAfter,
      predictionAlgorithm: predictionAlgorithm,
      predictionAlarmEnabled: predictionAlarmEnabled,
      predictionAlarmMmol: predictionAlarmMmol.clamp(1.5, min).toDouble(),
      glucoseUnit: glucoseUnit,
      server: server,
    );
  }

  Future<void> write(AlarmSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, s.enabled);
    await prefs.setDouble(_kMin, s.minMmol);
    await prefs.setDouble(_kMax, s.maxMmol);
    await prefs.setBool(_kStaleEnabled, s.staleAlarmEnabled);
    await prefs.setInt(_kStaleAfterMinutes, s.staleAfterMinutes);
    await prefs.setString(
      _kPredictionAlgorithm,
      s.predictionAlgorithm.storageValue,
    );
    await prefs.setBool(_kPredictionAlarmEnabled, s.predictionAlarmEnabled);
    await prefs.setDouble(_kPredictionAlarmMmol, s.predictionAlarmMmol);
    await prefs.setString(_kGlucoseUnit, s.glucoseUnit.storageValue);
    await prefs.setString(_kServer, s.server.storageValue);
  }
}
