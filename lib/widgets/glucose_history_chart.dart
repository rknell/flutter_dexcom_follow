import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/glucose_format.dart';
import '../app/prediction.dart';
import 'glucose_chart_window.dart';

class GlucoseHistoryChart extends StatefulWidget {
  const GlucoseHistoryChart({
    super.key,
    required this.history,
    this.prediction,
    required this.alarmMinMmol,
    required this.alarmMaxMmol,
  });

  final List<GlucoseEntry> history; // oldest-first
  final PredictionResult? prediction;
  final double alarmMinMmol;
  final double alarmMaxMmol;

  @override
  State<GlucoseHistoryChart> createState() => _GlucoseHistoryChartState();
}

class _GlucoseHistoryChartState extends State<GlucoseHistoryChart> {
  static const int _minVisiblePoints = 12;
  int? _visiblePoints; // null => show all

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final history = widget.history;
    if (history.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Not enough history yet to show a graph.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
          ),
        ),
      );
    }

    final totalPoints = history.length;
    final targetVisible =
        (_visiblePoints ?? totalPoints).clamp(_minVisiblePoints, totalPoints);
    final window = GlucoseChartWindow.forVisiblePoints(
      totalPoints: totalPoints,
      visiblePoints: targetVisible,
      minVisiblePoints: _minVisiblePoints,
    );
    final visiblePoints = window.visiblePoints;
    final startIdx = window.startIdx;
    final endIdx = window.endIdx;
    final displayedStartTime = formatLocalTimeFromIsoUtc(history[startIdx].timestamp);
    final displayedEndTime = formatLocalTimeFromIsoUtc(history[endIdx].timestamp);

    final spots = <FlSpot>[];
    for (var i = startIdx; i <= endIdx; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].mmol));
    }

    const minY = 2.0;
    const maxY = 22.0;

    final pred = widget.prediction;
    final predSpots = <FlSpot>[];
    if (pred != null && pred.nextPoints.isNotEmpty) {
      final lastIdx = (history.length - 1).toDouble();
      final lastY = history.last.mmol;
      predSpots.add(FlSpot(lastIdx, lastY));
      for (var i = 0; i < pred.nextPoints.length; i++) {
        predSpots.add(FlSpot(lastIdx + (i + 1).toDouble(), pred.nextPoints[i].mmol));
      }
    }

    final maxX = window.maxX;
    final minX = window.minX;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'History ($displayedStartTime–$displayedEndTime)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: scheme.onSurface.withValues(alpha: 0.10),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: scheme.onSurface.withValues(alpha: 0.10)),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(0),
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (visiblePoints / 4).clamp(1, 96).toDouble(),
                        getTitlesWidget: (value, meta) {
                          final idx = value.round().clamp(0, history.length - 1);
                          final t = formatLocalTimeFromIsoUtc(history[idx].timestamp);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              t,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.65),
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(14),
                      getTooltipColor: (_) => scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.round().clamp(0, history.length - 1);
                          final entry = history[idx];
                          final time = formatLocalTimeFromIsoUtc(entry.timestamp);
                          return LineTooltipItem(
                            '${formatMmol(entry.mmol)} mmol/L\n$time',
                            TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          );
                        }).toList(growable: false);
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      curveSmoothness: 0.22,
                      barWidth: 3,
                      color: scheme.primary,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.15),
                      ),
                      spots: spots,
                    ),
                    if (predSpots.length >= 2)
                      LineChartBarData(
                        isCurved: true,
                        curveSmoothness: 0.22,
                        barWidth: 3,
                        color: scheme.secondary.withValues(alpha: 0.95),
                        dashArray: const [8, 6],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            if (index == 0) {
                              return FlDotCirclePainter(
                                radius: 2.6,
                                color: scheme.secondary,
                                strokeWidth: 2,
                                strokeColor: scheme.surface,
                              );
                            }
                            return FlDotCirclePainter(
                              radius: 3.4,
                              color: scheme.secondary,
                              strokeWidth: 2,
                              strokeColor: scheme.surface,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(show: false),
                        spots: predSpots,
                      ),
                  ],
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: widget.alarmMinMmol,
                      color: scheme.error.withValues(alpha: 0.55),
                      strokeWidth: 1.5,
                      dashArray: [6, 6],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        style: TextStyle(
                          color: scheme.error.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        labelResolver: (_) => widget.alarmMinMmol.toStringAsFixed(1),
                      ),
                    ),
                    HorizontalLine(
                      y: widget.alarmMaxMmol,
                      color: scheme.tertiary.withValues(alpha: 0.55),
                      strokeWidth: 1.5,
                      dashArray: [6, 6],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        style: TextStyle(
                          color: scheme.tertiary.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        labelResolver: (_) => widget.alarmMaxMmol.toStringAsFixed(1),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    // Starts full (left), then moving right reduces visible points.
                    value: (totalPoints - targetVisible).toDouble(),
                    min: 0,
                    max: (totalPoints - _minVisiblePoints).toDouble(),
                    divisions: (totalPoints - _minVisiblePoints).clamp(1, 1000),
                    label: '$visiblePoints pts',
                    onChanged: (v) {
                      final hidden = v.round().clamp(0, totalPoints - _minVisiblePoints);
                      setState(() {
                        _visiblePoints =
                            (totalPoints - hidden).clamp(_minVisiblePoints, totalPoints);
                      });
                    },
                  ),
                ),
              ],
            ),
            if (predSpots.length >= 2) ...[
              const SizedBox(height: 10),
              Text(
                'Dashed line = 20‑minute forecast',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

