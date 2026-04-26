import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:flutter_dexcom_follow/app/background_monitor.dart';
import 'package:flutter_dexcom_follow/app/prediction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FEATURE: trend maps to stable Unicode arrows for notifications', () {
    expect(trendArrowForNotification(Trend.doubleup), '↑↑');
    expect(trendArrowForNotification(Trend.singleup), '↑');
    expect(trendArrowForNotification(Trend.fortyfiveup), '↗');
    expect(trendArrowForNotification(Trend.flat), '→');
    expect(trendArrowForNotification(Trend.fortyfivedown), '↘');
    expect(trendArrowForNotification(Trend.singledown), '↓');
    expect(trendArrowForNotification(Trend.doubledown), '↓↓');
  });

  test(
    'FEATURE: foreground notification subtitle shows 20-minute prediction',
    () {
      final prediction = PredictionResult(
        nextPoints: [
          PredictionPoint(at: DateTime.utc(2026, 4, 8, 10, 5), mmol: 5.8),
          PredictionPoint(at: DateTime.utc(2026, 4, 8, 10, 10), mmol: 5.9),
          PredictionPoint(at: DateTime.utc(2026, 4, 8, 10, 15), mmol: 6.0),
          PredictionPoint(at: DateTime.utc(2026, 4, 8, 10, 20), mmol: 6.1),
        ],
        slopeMmolPerMinute: 0.02,
        method: 'linear_regression',
      );

      expect(
        predictionTextForNotification(prediction),
        'Predicted 6.1 mmol/L in 20 min',
      );
      expect(
        predictionTextForNotification(null),
        '20-min prediction unavailable',
      );
    },
  );
}
