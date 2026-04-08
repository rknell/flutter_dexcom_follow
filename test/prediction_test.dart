import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:flutter_dexcom_follow/app/prediction.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseEntry _e(int minute, double mmol) {
  final t = DateTime.utc(2026, 4, 8, 10, minute);
  return GlucoseEntry(mgdl: 0, mmol: mmol, trend: Trend.flat, timestamp: t.toIso8601String());
}

void main() {
  test('FEATURE: linear regression predicts rising trend', () {
    // 8 readings, +0.1 mmol every 5 minutes.
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

    final p = predictNext20Minutes(historyOldestFirst: history);
    expect(p, isNotNull);
    final pred = p!;
    expect(pred.nextPoints.length, 4);
    // At +20 minutes (4 steps): should add about 0.4.
    expect(pred.nextPoints.last.mmol, closeTo(6.1, 0.15));
  });

  test('EDGE_CASE: returns null when insufficient history', () {
    final p = predictNext20Minutes(historyOldestFirst: <GlucoseEntry>[_e(0, 5.0), _e(5, 5.1)]);
    expect(p, isNull);
  });
}

