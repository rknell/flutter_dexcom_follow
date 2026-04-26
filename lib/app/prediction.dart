import 'dart:math' as math;

import 'package:dexcom_share_api/dexcom_share_api.dart';

enum PredictionAlgorithm {
  weightedLinearRegression,
  linearRegression,
  rollingAverage,
}

extension PredictionAlgorithmLabel on PredictionAlgorithm {
  String get storageValue => switch (this) {
    PredictionAlgorithm.weightedLinearRegression =>
      'weighted_linear_regression',
    PredictionAlgorithm.linearRegression => 'linear_regression',
    PredictionAlgorithm.rollingAverage => 'rolling_average',
  };

  String get displayName => switch (this) {
    PredictionAlgorithm.weightedLinearRegression =>
      'Weighted linear regression',
    PredictionAlgorithm.linearRegression => 'Linear regression',
    PredictionAlgorithm.rollingAverage => 'Rolling average',
  };

  String get shortName => switch (this) {
    PredictionAlgorithm.weightedLinearRegression => 'weighted regression',
    PredictionAlgorithm.linearRegression => 'linear regression',
    PredictionAlgorithm.rollingAverage => 'rolling average',
  };

  static PredictionAlgorithm fromStorageValue(String? value) {
    return PredictionAlgorithm.values.firstWhere(
      (v) => v.storageValue == value,
      orElse: () => PredictionAlgorithm.weightedLinearRegression,
    );
  }
}

enum PredictionQualityStatus { good, stale, sparse, noisy, implausible }

extension PredictionQualityStatusLabel on PredictionQualityStatus {
  String get displayName => switch (this) {
    PredictionQualityStatus.good => 'good',
    PredictionQualityStatus.stale => 'stale',
    PredictionQualityStatus.sparse => 'sparse',
    PredictionQualityStatus.noisy => 'noisy',
    PredictionQualityStatus.implausible => 'implausible',
  };
}

class PredictionPoint {
  final DateTime at;
  final double mmol;

  const PredictionPoint({required this.at, required this.mmol});
}

class PredictionQuality {
  final PredictionQualityStatus status;
  final int pointCount;
  final double windowMinutes;
  final double maxGapMinutes;
  final double latestAgeMinutes;
  final double residualStdDevMmol;
  final bool canAlarm;

  const PredictionQuality({
    required this.status,
    required this.pointCount,
    required this.windowMinutes,
    required this.maxGapMinutes,
    required this.latestAgeMinutes,
    required this.residualStdDevMmol,
    required this.canAlarm,
  });
}

class PredictionResult {
  final List<PredictionPoint> nextPoints; // typically 4 points (5/10/15/20)
  final double slopeMmolPerMinute;
  final PredictionAlgorithm algorithm;
  final PredictionQuality quality;

  const PredictionResult({
    required this.nextPoints,
    required this.slopeMmolPerMinute,
    required this.algorithm,
    required this.quality,
  });

  String get method => algorithm.storageValue;
}

class _RegressionResult {
  final double slope;
  final double intercept;

  const _RegressionResult({required this.slope, required this.intercept});
}

class _PreparedHistory {
  final List<GlucoseEntry> entries;
  final List<DateTime> times;
  final List<double> xs;
  final List<double> ys;

  const _PreparedHistory({
    required this.entries,
    required this.times,
    required this.xs,
    required this.ys,
  });
}

const double _kMaxAlarmGapMinutes = 7.5;
const double _kMaxAlarmLatestAgeMinutes = 12.0;
const double _kMaxAlarmResidualStdDevMmol = 0.25;
const double _kMaxPlausibleSlopeMmolPerMinute = 0.18;
const double _kMinPredictedMmol = 2.0;
const double _kMaxPredictedMmol = 22.0;

PredictionResult? predictNext20Minutes({
  required List<GlucoseEntry> historyOldestFirst,
  PredictionAlgorithm algorithm = PredictionAlgorithm.weightedLinearRegression,
  DateTime? nowUtc,
  int lookbackPoints = 8,
  int stepMinutes = 5,
  int steps = 4,
}) {
  final prepared = _prepareHistory(
    historyOldestFirst: historyOldestFirst,
    lookbackPoints: lookbackPoints,
  );
  if (prepared == null) return null;

  final slope = switch (algorithm) {
    PredictionAlgorithm.weightedLinearRegression => _weightedLinearRegression(
      prepared.xs,
      prepared.ys,
    ),
    PredictionAlgorithm.linearRegression => _linearRegression(
      prepared.xs,
      prepared.ys,
    ),
    PredictionAlgorithm.rollingAverage => _rollingAverageSlope(
      prepared.xs,
      prepared.ys,
    ),
  };
  if (slope == null) return null;

  final lastTime = prepared.times.last;
  final lastMmol = prepared.ys.last;
  final points = <PredictionPoint>[];
  var implausible = slope.abs() > _kMaxPlausibleSlopeMmolPerMinute;
  for (var i = 1; i <= steps; i++) {
    final minutesAhead = stepMinutes * i;
    final y = lastMmol + slope * minutesAhead;
    if (y < _kMinPredictedMmol || y > _kMaxPredictedMmol) {
      implausible = true;
    }
    points.add(
      PredictionPoint(
        at: lastTime.add(Duration(minutes: minutesAhead)),
        mmol: y.clamp(_kMinPredictedMmol, _kMaxPredictedMmol).toDouble(),
      ),
    );
  }

  final quality = _qualityFor(
    prepared: prepared,
    algorithm: algorithm,
    slope: slope,
    nowUtc: nowUtc ?? DateTime.now().toUtc(),
    implausible: implausible,
  );

  return PredictionResult(
    nextPoints: points,
    slopeMmolPerMinute: slope,
    algorithm: algorithm,
    quality: quality,
  );
}

_PreparedHistory? _prepareHistory({
  required List<GlucoseEntry> historyOldestFirst,
  required int lookbackPoints,
}) {
  if (historyOldestFirst.length < 3) return null;

  final byTimestamp = <int, GlucoseEntry>{};
  for (final entry in historyOldestFirst) {
    final time = DateTime.tryParse(entry.timestamp);
    if (time == null || !entry.mmol.isFinite) continue;
    byTimestamp[time.toUtc().millisecondsSinceEpoch] = entry;
  }
  if (byTimestamp.length < 3) return null;

  final orderedKeys = byTimestamp.keys.toList(growable: false)..sort();
  final ordered = orderedKeys
      .map((key) => byTimestamp[key]!)
      .toList(growable: false);
  final take = ordered.length >= lookbackPoints
      ? lookbackPoints
      : ordered.length;
  final window = ordered.sublist(ordered.length - take);
  if (window.length < 3) return null;

  final times = window.map((e) => DateTime.parse(e.timestamp).toUtc()).toList();
  final values = window.map((e) => e.mmol).toList();
  final t0 = times.first.millisecondsSinceEpoch.toDouble();
  final xs = times
      .map((t) => (t.millisecondsSinceEpoch.toDouble() - t0) / 60000.0)
      .toList(growable: false);

  return _PreparedHistory(entries: window, times: times, xs: xs, ys: values);
}

double? _linearRegression(List<double> xs, List<double> ys) {
  final weights = List<double>.filled(xs.length, 1.0, growable: false);
  return _weightedFit(xs, ys, weights)?.slope;
}

double? _weightedLinearRegression(List<double> xs, List<double> ys) {
  final last = xs.length - 1;
  final weights = List<double>.generate(xs.length, (i) {
    final ageFromLatest = last - i;
    return math.pow(0.72, ageFromLatest).toDouble();
  }, growable: false);
  return _weightedFit(xs, ys, weights)?.slope;
}

double? _rollingAverageSlope(List<double> xs, List<double> ys) {
  var weightedDelta = 0.0;
  var totalWeight = 0.0;
  final last = ys.length - 1;
  for (var i = 1; i < ys.length; i++) {
    final dt = xs[i] - xs[i - 1];
    if (dt <= 0) continue;
    final ageFromLatest = last - i;
    final weight = math.pow(0.72, ageFromLatest).toDouble();
    weightedDelta += ((ys[i] - ys[i - 1]) / dt) * weight;
    totalWeight += weight;
  }
  if (totalWeight == 0) return null;
  return weightedDelta / totalWeight;
}

_RegressionResult? _weightedFit(
  List<double> xs,
  List<double> ys,
  List<double> weights,
) {
  var sumW = 0.0;
  var sumX = 0.0;
  var sumY = 0.0;
  var sumXX = 0.0;
  var sumXY = 0.0;
  for (var i = 0; i < xs.length; i++) {
    final w = weights[i];
    final x = xs[i];
    final y = ys[i];
    sumW += w;
    sumX += w * x;
    sumY += w * y;
    sumXX += w * x * x;
    sumXY += w * x * y;
  }

  final denom = sumW * sumXX - sumX * sumX;
  if (denom.abs() < 1e-9) return null;
  final slope = (sumW * sumXY - sumX * sumY) / denom;
  final intercept = (sumY - slope * sumX) / sumW;
  return _RegressionResult(slope: slope, intercept: intercept);
}

PredictionQuality _qualityFor({
  required _PreparedHistory prepared,
  required PredictionAlgorithm algorithm,
  required double slope,
  required DateTime nowUtc,
  required bool implausible,
}) {
  final gaps = <double>[];
  for (var i = 1; i < prepared.times.length; i++) {
    gaps.add(
      prepared.times[i].difference(prepared.times[i - 1]).inSeconds / 60.0,
    );
  }
  final maxGap = gaps.isEmpty ? double.infinity : gaps.reduce(math.max);
  final latestAge = nowUtc.difference(prepared.times.last).inSeconds / 60.0;
  final windowMinutes =
      prepared.times.last.difference(prepared.times.first).inSeconds / 60.0;
  final residualStdDev = _residualStdDev(
    xs: prepared.xs,
    ys: prepared.ys,
    slope: slope,
    algorithm: algorithm,
  );

  final status = () {
    if (implausible) return PredictionQualityStatus.implausible;
    if (latestAge < 0 || latestAge > _kMaxAlarmLatestAgeMinutes) {
      return PredictionQualityStatus.stale;
    }
    if (prepared.entries.length < 4 ||
        maxGap > _kMaxAlarmGapMinutes ||
        windowMinutes < 10) {
      return PredictionQualityStatus.sparse;
    }
    if (residualStdDev > _kMaxAlarmResidualStdDevMmol) {
      return PredictionQualityStatus.noisy;
    }
    return PredictionQualityStatus.good;
  }();

  return PredictionQuality(
    status: status,
    pointCount: prepared.entries.length,
    windowMinutes: windowMinutes,
    maxGapMinutes: maxGap,
    latestAgeMinutes: latestAge,
    residualStdDevMmol: residualStdDev,
    canAlarm: status == PredictionQualityStatus.good,
  );
}

double _residualStdDev({
  required List<double> xs,
  required List<double> ys,
  required double slope,
  required PredictionAlgorithm algorithm,
}) {
  final intercept = switch (algorithm) {
    PredictionAlgorithm.weightedLinearRegression => _weightedFit(
      xs,
      ys,
      List<double>.generate(
        xs.length,
        (i) => math.pow(0.72, xs.length - 1 - i).toDouble(),
        growable: false,
      ),
    )?.intercept,
    PredictionAlgorithm.linearRegression => _weightedFit(
      xs,
      ys,
      List<double>.filled(xs.length, 1.0, growable: false),
    )?.intercept,
    PredictionAlgorithm.rollingAverage => null,
  };

  final predicted = <double>[];
  if (intercept != null) {
    for (final x in xs) {
      predicted.add(intercept + slope * x);
    }
  } else {
    for (var i = 0; i < xs.length; i++) {
      predicted.add(ys.last - slope * (xs.last - xs[i]));
    }
  }

  var sumSq = 0.0;
  for (var i = 0; i < ys.length; i++) {
    final residual = ys[i] - predicted[i];
    sumSq += residual * residual;
  }
  return math.sqrt(sumSq / ys.length);
}
