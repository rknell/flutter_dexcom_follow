import 'package:dexcom_share_api/dexcom_share_api.dart';

class PredictionPoint {
  final DateTime at;
  final double mmol;

  const PredictionPoint({required this.at, required this.mmol});
}

class PredictionResult {
  final List<PredictionPoint> nextPoints; // typically 4 points (5/10/15/20)
  final double slopeMmolPerMinute;
  final String method; // e.g. "linear_regression" or "rolling_average"

  const PredictionResult({
    required this.nextPoints,
    required this.slopeMmolPerMinute,
    required this.method,
  });
}

PredictionResult? predictNext20Minutes({
  required List<GlucoseEntry> historyOldestFirst,
  int lookbackPoints = 8,
  int stepMinutes = 5,
  int steps = 4,
}) {
  if (historyOldestFirst.length < 3) return null;
  final take = historyOldestFirst.length >= lookbackPoints
      ? lookbackPoints
      : historyOldestFirst.length;
  final window = historyOldestFirst.sublist(historyOldestFirst.length - take);

  final times = <DateTime>[];
  final values = <double>[];
  for (final e in window) {
    times.add(DateTime.parse(e.timestamp));
    values.add(e.mmol);
  }

  // Ensure time increases.
  for (var i = 1; i < times.length; i++) {
    if (!times[i].isAfter(times[i - 1])) {
      return _fallbackRollingAverage(
        historyOldestFirst: historyOldestFirst,
        stepMinutes: stepMinutes,
        steps: steps,
      );
    }
  }

  final t0 = times.first.millisecondsSinceEpoch.toDouble();
  final xs = times
      .map((t) => (t.millisecondsSinceEpoch.toDouble() - t0) / 60000.0)
      .toList(growable: false); // minutes since first
  final ys = values;

  // Simple least squares line fit y = a + b x
  // Big-O: O(n)
  final n = xs.length;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXX = 0.0;
  var sumXY = 0.0;
  for (var i = 0; i < n; i++) {
    final x = xs[i];
    final y = ys[i];
    sumX += x;
    sumY += y;
    sumXX += x * x;
    sumXY += x * y;
  }

  final denom = (n * sumXX - sumX * sumX);
  if (denom.abs() < 1e-9) {
    return _fallbackRollingAverage(
      historyOldestFirst: historyOldestFirst,
      stepMinutes: stepMinutes,
      steps: steps,
    );
  }

  final b = (n * sumXY - sumX * sumY) / denom; // mmol per minute
  final a = (sumY - b * sumX) / n;

  final lastTime = times.last;
  final lastX = xs.last;

  final points = <PredictionPoint>[];
  for (var i = 1; i <= steps; i++) {
    final minutesAhead = stepMinutes * i;
    final x = lastX + minutesAhead.toDouble();
    final y = a + b * x;
    points.add(PredictionPoint(at: lastTime.add(Duration(minutes: minutesAhead)), mmol: y));
  }

  return PredictionResult(nextPoints: points, slopeMmolPerMinute: b, method: 'linear_regression');
}

PredictionResult? _fallbackRollingAverage({
  required List<GlucoseEntry> historyOldestFirst,
  required int stepMinutes,
  required int steps,
}) {
  if (historyOldestFirst.length < 2) return null;
  final last = historyOldestFirst.last;
  final lastTime = DateTime.parse(last.timestamp);

  // Rolling average of deltas across the last up to 8 readings.
  final take = historyOldestFirst.length >= 8 ? 8 : historyOldestFirst.length;
  final window = historyOldestFirst.sublist(historyOldestFirst.length - take);
  var sumDelta = 0.0;
  var count = 0;
  for (var i = 1; i < window.length; i++) {
    sumDelta += (window[i].mmol - window[i - 1].mmol);
    count++;
  }
  if (count == 0) return null;
  final avgDeltaPerReading = sumDelta / count;
  final slopeMmolPerMinute = avgDeltaPerReading / stepMinutes;

  final points = <PredictionPoint>[];
  for (var i = 1; i <= steps; i++) {
    final minutesAhead = stepMinutes * i;
    final y = last.mmol + avgDeltaPerReading * i;
    points.add(PredictionPoint(at: lastTime.add(Duration(minutes: minutesAhead)), mmol: y));
  }
  return PredictionResult(
    nextPoints: points,
    slopeMmolPerMinute: slopeMmolPerMinute,
    method: 'rolling_average',
  );
}

