import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:flutter_dexcom_follow/app/background_monitor.dart';
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
}
