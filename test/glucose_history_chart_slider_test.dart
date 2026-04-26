import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_dexcom_follow/app/prediction.dart';
import 'package:flutter_dexcom_follow/app/alarm_settings.dart';
import 'package:flutter_dexcom_follow/widgets/glucose_history_chart.dart';

GlucoseEntry _entry(int idx) {
  final t = DateTime(2026, 1, 1, 0, idx * 5).toUtc();
  final mmol = 5.0 + (idx / 20.0);
  return GlucoseEntry(
    mgdl: (mmol * 18).round(),
    mmol: mmol,
    trend: Trend.flat,
    timestamp: t.toIso8601String(),
  );
}

void main() {
  testWidgets(
    '🚀 FEATURE: slider limits visible points and preserves prediction',
    (tester) async {
      final history = List<GlucoseEntry>.generate(60, _entry, growable: false);
      final prediction = PredictionResult(
        nextPoints: [
          PredictionPoint(at: DateTime(2026, 1, 1, 6, 5), mmol: 8.1),
          PredictionPoint(at: DateTime(2026, 1, 1, 6, 10), mmol: 8.2),
        ],
        slopeMmolPerMinute: 0.01,
        algorithm: PredictionAlgorithm.weightedLinearRegression,
        quality: const PredictionQuality(
          status: PredictionQualityStatus.good,
          pointCount: 8,
          windowMinutes: 35,
          maxGapMinutes: 5,
          latestAgeMinutes: 1,
          residualStdDevMmol: 0,
          canAlarm: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: Scaffold(
            body: Center(
              child: GlucoseHistoryChart(
                history: history,
                prediction: prediction,
                alarmMinMmol: 4.0,
                alarmMaxMmol: 10.0,
                unit: GlucoseUnit.mmol,
              ),
            ),
          ),
        ),
      );

      LineChartData chartData() =>
          tester.widget<LineChart>(find.byType(LineChart)).data;

      final before = chartData();
      expect(before.maxX, (history.length - 1).toDouble());
      expect(before.minX, 0.0);
      expect(before.lineBarsData.length, 2);
      expect(before.lineBarsData[1].spots.first.x, before.maxX);

      // Drag slider right to reduce visible points; chart should remain right-anchored.
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      await tester.drag(slider, const Offset(300, 0));
      await tester.pump();

      final after = chartData();
      expect(after.maxX, (history.length - 1).toDouble());
      expect(after.minX, greaterThan(0.0));
      expect(after.lineBarsData.length, 2);
      expect(after.lineBarsData[1].spots.first.x, after.maxX);
    },
  );
}
