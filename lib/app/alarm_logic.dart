/// Glucose at or below this level always triggers the critical (panic) alarm,
/// even when user-configurable alarms are turned off.
const double kCriticalLowMmol = 3.1;

/// Critical alarms may repeat more often than standard out-of-range alarms.
const Duration kCriticalLowRepeatInterval = Duration(seconds: 15);

/// Predicted lows are safety alerts, but less urgent than a current critical low.
const Duration kPredictedLowRepeatInterval = Duration(minutes: 5);

/// Keep predicted-low alarms below the one-decimal display boundary for 3.1.
const double kPredictedLowAlarmMmol = kCriticalLowMmol - 0.05;

class AlarmDecision {
  final bool shouldTrigger;
  final String? reason;

  const AlarmDecision({required this.shouldTrigger, this.reason});
}

class AlarmPolicy {
  final double minMmol;
  final double maxMmol;
  final Duration minRepeatInterval;

  const AlarmPolicy({
    this.minMmol = 3.9,
    this.maxMmol = 14.0,
    this.minRepeatInterval = const Duration(minutes: 1),
  });
}

class AlarmState {
  final String? lastAlarmedTimestampIsoUtc;
  final DateTime? lastAlarmedAt;
  final DateTime? lastCriticalLowAlarmAt;
  final DateTime? lastPredictedLowAlarmAt;

  const AlarmState({
    this.lastAlarmedTimestampIsoUtc,
    this.lastAlarmedAt,
    this.lastCriticalLowAlarmAt,
    this.lastPredictedLowAlarmAt,
  });

  AlarmState copyWith({
    String? lastAlarmedTimestampIsoUtc,
    DateTime? lastAlarmedAt,
    DateTime? lastCriticalLowAlarmAt,
    DateTime? lastPredictedLowAlarmAt,
  }) {
    return AlarmState(
      lastAlarmedTimestampIsoUtc:
          lastAlarmedTimestampIsoUtc ?? this.lastAlarmedTimestampIsoUtc,
      lastAlarmedAt: lastAlarmedAt ?? this.lastAlarmedAt,
      lastCriticalLowAlarmAt:
          lastCriticalLowAlarmAt ?? this.lastCriticalLowAlarmAt,
      lastPredictedLowAlarmAt:
          lastPredictedLowAlarmAt ?? this.lastPredictedLowAlarmAt,
    );
  }
}

bool isDataStale({
  required DateTime now,
  required DateTime readingTimeUtc,
  required Duration staleAfter,
}) {
  // Big-O: O(1)
  return now.difference(readingTimeUtc) > staleAfter;
}

AlarmDecision evaluateAlarm({
  required AlarmPolicy policy,
  required AlarmState state,
  required double mmol,
  required String timestampIsoUtc,
  required DateTime now,
  required bool isEnabled,
}) {
  if (!isEnabled) {
    return const AlarmDecision(shouldTrigger: false, reason: 'disabled');
  }

  final outOfRange = mmol <= policy.minMmol || mmol >= policy.maxMmol;
  if (!outOfRange) {
    return const AlarmDecision(shouldTrigger: false, reason: 'in-range');
  }

  final lastAt = state.lastAlarmedAt;
  if (lastAt != null && now.difference(lastAt) < policy.minRepeatInterval) {
    return const AlarmDecision(shouldTrigger: false, reason: 'repeat-interval');
  }

  return const AlarmDecision(shouldTrigger: true);
}

/// Severe hypoglycaemia band: always evaluated; ignores [AlarmSettings.enabled].
AlarmDecision evaluateCriticalLowAlarm({
  required AlarmState state,
  required double mmol,
  required DateTime now,
}) {
  if (mmol > kCriticalLowMmol) {
    return const AlarmDecision(
      shouldTrigger: false,
      reason: 'above-critical-low',
    );
  }

  final lastAt = state.lastCriticalLowAlarmAt;
  if (lastAt != null && now.difference(lastAt) < kCriticalLowRepeatInterval) {
    return const AlarmDecision(
      shouldTrigger: false,
      reason: 'critical-repeat-interval',
    );
  }

  return const AlarmDecision(shouldTrigger: true, reason: 'critical-low');
}

/// Future severe hypoglycaemia band: always evaluated; ignores [AlarmSettings.enabled].
AlarmDecision evaluatePredictedLowAlarm({
  required AlarmState state,
  required double? predictedMmol,
  required DateTime now,
  bool predictionCanAlarm = true,
}) {
  if (predictedMmol == null) {
    return const AlarmDecision(
      shouldTrigger: false,
      reason: 'prediction-unavailable',
    );
  }

  if (!predictionCanAlarm) {
    return const AlarmDecision(
      shouldTrigger: false,
      reason: 'prediction-quality-insufficient',
    );
  }

  if (predictedMmol > kPredictedLowAlarmMmol) {
    return const AlarmDecision(
      shouldTrigger: false,
      reason: 'prediction-above-critical-low',
    );
  }

  final lastAt = state.lastPredictedLowAlarmAt;
  if (lastAt != null && now.difference(lastAt) < kPredictedLowRepeatInterval) {
    return const AlarmDecision(
      shouldTrigger: false,
      reason: 'predicted-low-repeat-interval',
    );
  }

  return const AlarmDecision(shouldTrigger: true, reason: 'predicted-low');
}
