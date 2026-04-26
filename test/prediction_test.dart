import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:flutter_dexcom_follow/app/prediction.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseEntry _e(int minute, double mmol) {
  final t = DateTime.utc(2026, 4, 8, 10, minute);
  return GlucoseEntry(
    mgdl: 0,
    mmol: mmol,
    trend: Trend.flat,
    timestamp: t.toIso8601String(),
  );
}

void main() {
  test('FEATURE: weighted linear regression predicts rising trend', () {
    final history = <GlucoseEntry>[
      _e(0, 5.0),
      _e(5, 5.1),
      _e(10, 5.2),
      _e(15, 5.3),
      _e(20, 5.4),
      _e(25, 5.5),
      _e(30, 5.6),
      _e(35, 5.7),
    ];

    final p = predictNext20Minutes(
      historyOldestFirst: history,
      nowUtc: DateTime.utc(2026, 4, 8, 10, 36),
    );
    expect(p, isNotNull);
    final pred = p!;
    expect(pred.algorithm, PredictionAlgorithm.weightedLinearRegression);
    expect(pred.quality.status, PredictionQualityStatus.good);
    expect(pred.quality.canAlarm, true);
    expect(pred.nextPoints.length, 4);
    expect(pred.nextPoints.last.mmol, closeTo(6.1, 0.15));
  });

  test('FEATURE: selected linear regression algorithm is honored', () {
    final p = predictNext20Minutes(
      historyOldestFirst: <GlucoseEntry>[
        _e(0, 5.0),
        _e(5, 5.1),
        _e(10, 5.2),
        _e(15, 5.3),
      ],
      algorithm: PredictionAlgorithm.linearRegression,
      nowUtc: DateTime.utc(2026, 4, 8, 10, 16),
    );

    expect(p?.algorithm, PredictionAlgorithm.linearRegression);
    expect(p?.method, 'linear_regression');
  });

  test(
    'REGRESSION: unordered and duplicate readings are sorted and deduped',
    () {
      final p = predictNext20Minutes(
        historyOldestFirst: <GlucoseEntry>[
          _e(10, 5.2),
          _e(0, 5.0),
          _e(5, 5.1),
          _e(5, 5.15),
          _e(15, 5.3),
        ],
        nowUtc: DateTime.utc(2026, 4, 8, 10, 16),
      );

      expect(p, isNotNull);
      expect(p!.nextPoints.last.mmol, greaterThan(5.3));
    },
  );

  test('SAFETY: stale predictions are displayable but cannot alarm', () {
    final p = predictNext20Minutes(
      historyOldestFirst: <GlucoseEntry>[
        _e(0, 5.0),
        _e(5, 4.8),
        _e(10, 4.6),
        _e(15, 4.4),
      ],
      nowUtc: DateTime.utc(2026, 4, 8, 10, 40),
    );

    expect(p, isNotNull);
    expect(p!.quality.status, PredictionQualityStatus.stale);
    expect(p.quality.canAlarm, false);
  });

  test('SAFETY: sparse predictions are displayable but cannot alarm', () {
    final p = predictNext20Minutes(
      historyOldestFirst: <GlucoseEntry>[
        _e(0, 5.0),
        _e(5, 4.8),
        _e(30, 4.5),
        _e(35, 4.4),
      ],
      nowUtc: DateTime.utc(2026, 4, 8, 10, 36),
    );

    expect(p, isNotNull);
    expect(p!.quality.status, PredictionQualityStatus.sparse);
    expect(p.quality.canAlarm, false);
  });

  test('EDGE_CASE: returns null when insufficient history', () {
    final p = predictNext20Minutes(
      historyOldestFirst: <GlucoseEntry>[_e(0, 5.0), _e(5, 5.1)],
      nowUtc: DateTime.utc(2026, 4, 8, 10, 6),
    );
    expect(p, isNull);
  });
}
