import 'package:shared_preferences/shared_preferences.dart';

class AlarmSettings {
  final bool enabled;
  final double minMmol;
  final double maxMmol;
  final bool staleAlarmEnabled;
  final int staleAfterMinutes;

  const AlarmSettings({
    required this.enabled,
    required this.minMmol,
    required this.maxMmol,
    required this.staleAlarmEnabled,
    required this.staleAfterMinutes,
  });

  AlarmSettings copyWith({
    bool? enabled,
    double? minMmol,
    double? maxMmol,
    bool? staleAlarmEnabled,
    int? staleAfterMinutes,
  }) {
    return AlarmSettings(
      enabled: enabled ?? this.enabled,
      minMmol: minMmol ?? this.minMmol,
      maxMmol: maxMmol ?? this.maxMmol,
      staleAlarmEnabled: staleAlarmEnabled ?? this.staleAlarmEnabled,
      staleAfterMinutes: staleAfterMinutes ?? this.staleAfterMinutes,
    );
  }
}

class AlarmSettingsStore {
  static const _kEnabled = 'alarm.enabled';
  static const _kMin = 'alarm.minMmol';
  static const _kMax = 'alarm.maxMmol';
  static const _kStaleEnabled = 'alarm.stale.enabled';
  static const _kStaleAfterMinutes = 'alarm.stale.afterMinutes';

  static const AlarmSettings defaults = AlarmSettings(
    enabled: true,
    minMmol: 3.9,
    maxMmol: 14.0,
    staleAlarmEnabled: true,
    staleAfterMinutes: 15,
  );

  Future<AlarmSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabled) ?? defaults.enabled;
    final min = prefs.getDouble(_kMin) ?? defaults.minMmol;
    final max = prefs.getDouble(_kMax) ?? defaults.maxMmol;
    final staleEnabled = prefs.getBool(_kStaleEnabled) ?? defaults.staleAlarmEnabled;
    final staleAfter = prefs.getInt(_kStaleAfterMinutes) ?? defaults.staleAfterMinutes;
    return AlarmSettings(
      enabled: enabled,
      minMmol: min,
      maxMmol: max,
      staleAlarmEnabled: staleEnabled,
      staleAfterMinutes: staleAfter,
    );
  }

  Future<void> write(AlarmSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, s.enabled);
    await prefs.setDouble(_kMin, s.minMmol);
    await prefs.setDouble(_kMax, s.maxMmol);
    await prefs.setBool(_kStaleEnabled, s.staleAlarmEnabled);
    await prefs.setInt(_kStaleAfterMinutes, s.staleAfterMinutes);
  }
}

