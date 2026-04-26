import 'package:flutter_dexcom_follow/app/alarm_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alarm logic', () {
    test('REGRESSION: low triggers when mmol is <= min', () {
      final decision = evaluateAlarm(
        policy: AlarmPolicy(minMmol: 3.9, maxMmol: 14.0),
        state: const AlarmState(),
        mmol: 3.9,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 10),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, true);
    });

    test('REGRESSION: in-range does not trigger', () {
      final decision = evaluateAlarm(
        policy: AlarmPolicy(minMmol: 3.9, maxMmol: 14.0),
        state: const AlarmState(),
        mmol: 6.0,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 10),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'in-range');
    });

    test('REGRESSION: repeat interval blocks frequent new-reading alarms', () {
      final decision = evaluateAlarm(
        policy: AlarmPolicy(
          minMmol: 3.9,
          maxMmol: 14.0,
          minRepeatInterval: const Duration(minutes: 1),
        ),
        state: AlarmState(
          lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
          lastAlarmedAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
        ),
        mmol: 3.7,
        timestampIsoUtc: '2026-04-08T10:01:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 59),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'repeat-interval');
    });

    test('FEATURE: same reading does not retrigger after repeat interval', () {
      final decision = evaluateAlarm(
        policy: AlarmPolicy(
          minMmol: 3.9,
          maxMmol: 14.0,
          minRepeatInterval: const Duration(minutes: 1),
        ),
        state: AlarmState(
          lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
          lastAlarmedAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
        ),
        mmol: 3.7,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 5, 1),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'no-new-reading');
    });

    test(
      'FEATURE: new out-of-range reading can trigger after repeat interval',
      () {
        final decision = evaluateAlarm(
          policy: AlarmPolicy(
            minMmol: 3.9,
            maxMmol: 14.0,
            minRepeatInterval: const Duration(minutes: 1),
          ),
          state: AlarmState(
            lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
            lastAlarmedAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
          ),
          mmol: 3.7,
          timestampIsoUtc: '2026-04-08T10:05:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 5, 1),
          isEnabled: true,
        );

        expect(decision.shouldTrigger, true);
      },
    );

    test('FEATURE: high triggers when mmol is >= max', () {
      final decision = evaluateAlarm(
        policy: AlarmPolicy(minMmol: 3.9, maxMmol: 14.0),
        state: const AlarmState(),
        mmol: 14.0,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, true);
    });

    test('REGRESSION: disabled alarm never triggers', () {
      final decision = evaluateAlarm(
        policy: AlarmPolicy(minMmol: 3.9, maxMmol: 14.0),
        state: const AlarmState(),
        mmol: 3.0,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        isEnabled: false,
      );

      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'disabled');
    });
  });

  group('critical low alarm', () {
    test('REGRESSION: at or below 3.1 triggers even with no prior state', () {
      final decision = evaluateCriticalLowAlarm(
        state: const AlarmState(),
        mmol: 3.1,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
      );
      expect(decision.shouldTrigger, true);
      expect(decision.reason, 'critical-low');
    });

    test('REGRESSION: above 3.1 does not trigger critical', () {
      final decision = evaluateCriticalLowAlarm(
        state: const AlarmState(),
        mmol: 3.15,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
      );
      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'above-critical-low');
    });

    test(
      'FEATURE: critical blocks same reading even after repeat interval',
      () {
        final decision = evaluateCriticalLowAlarm(
          state: AlarmState(
            lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
            lastCriticalLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
          ),
          mmol: 2.9,
          timestampIsoUtc: '2026-04-08T10:00:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 5, 0),
        );
        expect(decision.shouldTrigger, false);
        expect(decision.reason, 'no-new-reading');
      },
    );

    test(
      'REGRESSION: critical repeat interval blocks rapid new-reading retrigger',
      () {
        final decision = evaluateCriticalLowAlarm(
          state: AlarmState(
            lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
            lastCriticalLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
          ),
          mmol: 2.9,
          timestampIsoUtc: '2026-04-08T10:01:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 0, 10),
        );
        expect(decision.shouldTrigger, false);
        expect(decision.reason, 'critical-repeat-interval');
      },
    );

    test(
      'FEATURE: critical can trigger on new reading after repeat interval',
      () {
        final decision = evaluateCriticalLowAlarm(
          state: AlarmState(
            lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
            lastCriticalLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
          ),
          mmol: 2.8,
          timestampIsoUtc: '2026-04-08T10:05:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 5, 0),
        );
        expect(decision.shouldTrigger, true);
      },
    );
  });

  group('predicted low alarm', () {
    test(
      'REGRESSION: below display threshold triggers predicted-low alert',
      () {
        final decision = evaluatePredictedLowAlarm(
          state: const AlarmState(),
          predictedMmol: 3.04,
          timestampIsoUtc: '2026-04-08T10:00:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        );
        expect(decision.shouldTrigger, true);
        expect(decision.reason, 'predicted-low');
      },
    );

    test(
      'REGRESSION: near or above 3.1 display boundary does not trigger predicted-low alert',
      () {
        final nearThreshold = evaluatePredictedLowAlarm(
          state: const AlarmState(),
          predictedMmol: 3.06,
          timestampIsoUtc: '2026-04-08T10:00:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        );
        final atThreshold = evaluatePredictedLowAlarm(
          state: const AlarmState(),
          predictedMmol: 3.1,
          timestampIsoUtc: '2026-04-08T10:00:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        );
        final aboveThreshold = evaluatePredictedLowAlarm(
          state: const AlarmState(),
          predictedMmol: 3.11,
          timestampIsoUtc: '2026-04-08T10:00:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        );

        expect(nearThreshold.shouldTrigger, false);
        expect(nearThreshold.reason, 'prediction-above-critical-low');
        expect(atThreshold.shouldTrigger, false);
        expect(atThreshold.reason, 'prediction-above-critical-low');
        expect(aboveThreshold.shouldTrigger, false);
        expect(aboveThreshold.reason, 'prediction-above-critical-low');
      },
    );

    test(
      'SAFETY: insufficient prediction quality blocks predicted-low alert',
      () {
        final decision = evaluatePredictedLowAlarm(
          state: const AlarmState(),
          predictedMmol: 2.8,
          timestampIsoUtc: '2026-04-08T10:00:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 0, 0),
          predictionCanAlarm: false,
        );
        expect(decision.shouldTrigger, false);
        expect(decision.reason, 'prediction-quality-insufficient');
      },
    );

    test(
      'FEATURE: predicted-low blocks same reading even after repeat interval',
      () {
        final decision = evaluatePredictedLowAlarm(
          state: AlarmState(
            lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
            lastPredictedLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
          ),
          predictedMmol: 2.9,
          timestampIsoUtc: '2026-04-08T10:00:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 5, 0),
        );
        expect(decision.shouldTrigger, false);
        expect(decision.reason, 'no-new-reading');
      },
    );

    test(
      'REGRESSION: predicted-low repeat interval blocks rapid new-reading retrigger',
      () {
        final decision = evaluatePredictedLowAlarm(
          state: AlarmState(
            lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
            lastPredictedLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
          ),
          predictedMmol: 2.9,
          timestampIsoUtc: '2026-04-08T10:01:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 4, 59),
        );
        expect(decision.shouldTrigger, false);
        expect(decision.reason, 'predicted-low-repeat-interval');
      },
    );

    test('FEATURE: predicted-low alarm can be disabled', () {
      final decision = evaluatePredictedLowAlarm(
        state: const AlarmState(),
        predictedMmol: 2.8,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        isEnabled: false,
      );
      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'prediction-disabled');
    });

    test(
      'FEATURE: predicted-low can trigger on new reading after repeat interval',
      () {
        final decision = evaluatePredictedLowAlarm(
          state: AlarmState(
            lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
            lastPredictedLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
          ),
          predictedMmol: 2.8,
          timestampIsoUtc: '2026-04-08T10:05:00.000Z',
          now: DateTime.utc(2026, 4, 8, 10, 5, 0),
        );
        expect(decision.shouldTrigger, true);
      },
    );

    test('EDGE_CASE: unavailable prediction does not trigger', () {
      final decision = evaluatePredictedLowAlarm(
        state: const AlarmState(),
        predictedMmol: null,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
      );
      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'prediction-unavailable');
    });
  });

  group('stale detection', () {
    test('REGRESSION: stale after threshold', () {
      final now = DateTime.utc(2026, 4, 8, 10, 15, 1);
      final reading = DateTime.utc(2026, 4, 8, 10, 0, 0);
      expect(
        isDataStale(
          now: now,
          readingTimeUtc: reading,
          staleAfter: const Duration(minutes: 15),
        ),
        true,
      );
    });

    test('REGRESSION: not stale at exactly threshold', () {
      final now = DateTime.utc(2026, 4, 8, 10, 15, 0);
      final reading = DateTime.utc(2026, 4, 8, 10, 0, 0);
      expect(
        isDataStale(
          now: now,
          readingTimeUtc: reading,
          staleAfter: const Duration(minutes: 15),
        ),
        false,
      );
    });
  });

  group('no-data alarm', () {
    test('FEATURE: no-data alarm can trigger with no prior state', () {
      final decision = evaluateNoDataAlarm(
        state: const AlarmState(),
        now: DateTime.utc(2026, 4, 8, 10, 15, 1),
      );

      expect(decision.shouldTrigger, true);
      expect(decision.reason, 'no-data');
    });

    test(
      'FEATURE: no-data alarm repeats no more often than every 5 minutes',
      () {
        final decision = evaluateNoDataAlarm(
          state: AlarmState(lastAlarmedAt: DateTime.utc(2026, 4, 8, 10, 15, 1)),
          now: DateTime.utc(2026, 4, 8, 10, 20, 0),
        );

        expect(decision.shouldTrigger, false);
        expect(decision.reason, 'no-data-repeat-interval');
      },
    );

    test('FEATURE: no-data alarm can repeat after 5 minutes', () {
      final decision = evaluateNoDataAlarm(
        state: AlarmState(lastAlarmedAt: DateTime.utc(2026, 4, 8, 10, 15, 1)),
        now: DateTime.utc(2026, 4, 8, 10, 20, 1),
      );

      expect(decision.shouldTrigger, true);
    });
  });
}
