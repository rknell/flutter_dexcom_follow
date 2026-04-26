import 'package:flutter/foundation.dart';

@immutable
class GlucoseChartWindow {
  final int totalPoints;
  final int visiblePoints;
  final int startIdx;
  final int endIdx;
  final double minX;
  final double maxX;

  const GlucoseChartWindow._({
    required this.totalPoints,
    required this.visiblePoints,
    required this.startIdx,
    required this.endIdx,
    required this.minX,
    required this.maxX,
  });

  /// Computes a right-anchored chart window (newest point on the right edge).
  ///
  /// Increasing [zoom] reduces [visiblePoints] while keeping [maxX] pinned to
  /// the newest datapoint.
  factory GlucoseChartWindow.forHistory({
    required int totalPoints,
    required double zoom,
    int minVisiblePoints = 12,
  }) {
    if (totalPoints <= 0) {
      return const GlucoseChartWindow._(
        totalPoints: 0,
        visiblePoints: 0,
        startIdx: 0,
        endIdx: 0,
        minX: 0,
        maxX: 0,
      );
    }

    final clampedZoom = zoom.clamp(1.0, 50.0).toDouble();
    final rawVisible = (totalPoints / clampedZoom).round();
    final visible = rawVisible.clamp(minVisiblePoints, totalPoints);

    final end = totalPoints - 1;
    final start = (totalPoints - visible).clamp(0, end);

    final maxX = end.toDouble();
    final minX = (maxX - (visible - 1)).clamp(0.0, maxX).toDouble();

    return GlucoseChartWindow._(
      totalPoints: totalPoints,
      visiblePoints: visible,
      startIdx: start,
      endIdx: end,
      minX: minX,
      maxX: maxX,
    );
  }

  /// Computes a right-anchored chart window with an explicit [visiblePoints]
  /// target.
  factory GlucoseChartWindow.forVisiblePoints({
    required int totalPoints,
    required int visiblePoints,
    int minVisiblePoints = 12,
  }) {
    if (totalPoints <= 0) {
      return const GlucoseChartWindow._(
        totalPoints: 0,
        visiblePoints: 0,
        startIdx: 0,
        endIdx: 0,
        minX: 0,
        maxX: 0,
      );
    }

    final visible = visiblePoints.clamp(minVisiblePoints, totalPoints);
    final end = totalPoints - 1;
    final start = (totalPoints - visible).clamp(0, end);

    final maxX = end.toDouble();
    final minX = (maxX - (visible - 1)).clamp(0.0, maxX).toDouble();

    return GlucoseChartWindow._(
      totalPoints: totalPoints,
      visiblePoints: visible,
      startIdx: start,
      endIdx: end,
      minX: minX,
      maxX: maxX,
    );
  }
}

