import 'package:flutter_dexcom_follow/app/alarm_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('alarm logic', () {
    test('REGRESSION: low triggers when mmol is <= min', () {
      final policy = AlarmPolicy(minMmol: 3.9, maxMmol: 14.0);
      final state = AlarmState();

      final decision = evaluateAlarm(
        policy: policy,
        state: state,
        mmol: 3.9,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 10),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, true);
    });

    test('REGRESSION: in-range does not trigger', () {
      final policy = AlarmPolicy(minMmol: 3.9, maxMmol: 14.0);
      final state = AlarmState();

      final decision = evaluateAlarm(
        policy: policy,
        state: state,
        mmol: 6.0,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 10),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'in-range');
    });

    test('REGRESSION: repeat interval blocks frequent alarms', () {
      final policy = AlarmPolicy(
        minMmol: 3.9,
        maxMmol: 14.0,
        minRepeatInterval: const Duration(minutes: 1),
      );

      final decision = evaluateAlarm(
        policy: policy,
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

    test('FEATURE: repeats after one minute while still low', () {
      final policy = AlarmPolicy(
        minMmol: 3.9,
        maxMmol: 14.0,
        minRepeatInterval: const Duration(minutes: 1),
      );

      final decision = evaluateAlarm(
        policy: policy,
        state: AlarmState(
          lastAlarmedTimestampIsoUtc: '2026-04-08T10:00:00.000Z',
          lastAlarmedAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
        ),
        mmol: 3.7,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 1, 1),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, true);
    });

    test('FEATURE: high triggers when mmol is >= max', () {
      final policy = AlarmPolicy(minMmol: 3.9, maxMmol: 14.0);

      final decision = evaluateAlarm(
        policy: policy,
        state: const AlarmState(),
        mmol: 14.0,
        timestampIsoUtc: '2026-04-08T10:00:00.000Z',
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        isEnabled: true,
      );

      expect(decision.shouldTrigger, true);
    });

    test('REGRESSION: disabled alarm never triggers', () {
      final policy = AlarmPolicy(minMmol: 3.9, maxMmol: 14.0);

      final decision = evaluateAlarm(
        policy: policy,
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
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
      );
      expect(decision.shouldTrigger, true);
      expect(decision.reason, 'critical-low');
    });

    test('REGRESSION: above 3.1 does not trigger critical', () {
      final decision = evaluateCriticalLowAlarm(
        state: const AlarmState(),
        mmol: 3.15,
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
      );
      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'above-critical-low');
    });

    test('REGRESSION: critical repeat interval blocks rapid retrigger', () {
      final decision = evaluateCriticalLowAlarm(
        state: AlarmState(
          lastCriticalLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
        ),
        mmol: 2.9,
        now: DateTime.utc(2026, 4, 8, 10, 0, 10),
      );
      expect(decision.shouldTrigger, false);
      expect(decision.reason, 'critical-repeat-interval');
    });

    test('FEATURE: critical can retrigger after repeat interval', () {
      final decision = evaluateCriticalLowAlarm(
        state: AlarmState(
          lastCriticalLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
        ),
        mmol: 2.8,
        now: DateTime.utc(2026, 4, 8, 10, 0, 16),
      );
      expect(decision.shouldTrigger, true);
    });
  });

  group('predicted low alarm', () {
    test('REGRESSION: below 3.1 triggers predicted-low alert', () {
      final decision = evaluatePredictedLowAlarm(
        state: const AlarmState(),
        predictedMmol: 3.09,
        now: DateTime.utc(2026, 4, 8, 10, 0, 0),
      );
      expect(decision.shouldTrigger, true);
      expect(decision.reason, 'predicted-low');
    });

    test(
      'REGRESSION: at or above 3.1 does not trigger predicted-low alert',
      () {
        final atThreshold = evaluatePredictedLowAlarm(
          state: const AlarmState(),
          predictedMmol: 3.1,
          now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        );
        final aboveThreshold = evaluatePredictedLowAlarm(
          state: const AlarmState(),
          predictedMmol: 3.11,
          now: DateTime.utc(2026, 4, 8, 10, 0, 0),
        );

        expect(atThreshold.shouldTrigger, false);
        expect(atThreshold.reason, 'prediction-above-critical-low');
        expect(aboveThreshold.shouldTrigger, false);
        expect(aboveThreshold.reason, 'prediction-above-critical-low');
      },
    );

    test(
      'REGRESSION: predicted-low repeat interval blocks rapid retrigger',
      () {
        final decision = evaluatePredictedLowAlarm(
          state: AlarmState(
            lastPredictedLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
          ),
          predictedMmol: 2.9,
          now: DateTime.utc(2026, 4, 8, 10, 4, 59),
        );
        expect(decision.shouldTrigger, false);
        expect(decision.reason, 'predicted-low-repeat-interval');
      },
    );

    test('FEATURE: predicted-low can retrigger after repeat interval', () {
      final decision = evaluatePredictedLowAlarm(
        state: AlarmState(
          lastPredictedLowAlarmAt: DateTime.utc(2026, 4, 8, 10, 0, 0),
        ),
        predictedMmol: 2.8,
        now: DateTime.utc(2026, 4, 8, 10, 5, 0),
      );
      expect(decision.shouldTrigger, true);
    });

    test('EDGE_CASE: unavailable prediction does not trigger', () {
      final decision = evaluatePredictedLowAlarm(
        state: const AlarmState(),
        predictedMmol: null,
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
}
