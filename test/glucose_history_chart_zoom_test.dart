import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_dexcom_follow/widgets/glucose_chart_window.dart';

void main() {
  test('🛡️ REGRESSION: chart window keeps newest data on right', () {
    final total = 100;
    final initial = GlucoseChartWindow.forVisiblePoints(
      totalPoints: total,
      visiblePoints: total,
    );
    expect(initial.maxX, (total - 1).toDouble());
    expect(initial.minX, 0.0);
    expect(initial.visiblePoints, total);

    final zoomed = GlucoseChartWindow.forVisiblePoints(
      totalPoints: total,
      visiblePoints: 50,
    );
    expect(zoomed.maxX, (total - 1).toDouble());
    expect(zoomed.minX, greaterThan(0.0));
    expect(zoomed.visiblePoints, lessThan(total));
    expect(zoomed.endIdx, total - 1);
  });
}
