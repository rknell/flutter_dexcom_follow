import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/alarm_settings.dart';
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
    required this.idealMinMmol,
    required this.idealMaxMmol,
    required this.unit,
  });

  final List<GlucoseEntry> history; // oldest-first
  final PredictionResult? prediction;
  final double alarmMinMmol;
  final double alarmMaxMmol;
  final double idealMinMmol;
  final double idealMaxMmol;
  final GlucoseUnit unit;

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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      );
    }

    final totalPoints = history.length;
    final targetVisible = (_visiblePoints ?? totalPoints).clamp(
      _minVisiblePoints,
      totalPoints,
    );
    final window = GlucoseChartWindow.forVisiblePoints(
      totalPoints: totalPoints,
      visiblePoints: targetVisible,
      minVisiblePoints: _minVisiblePoints,
    );
    final visiblePoints = window.visiblePoints;
    final startIdx = window.startIdx;
    final endIdx = window.endIdx;
    final displayedStartTime = formatLocalTimeFromIsoUtc(
      history[startIdx].timestamp,
    );
    final displayedEndTime = formatLocalTimeFromIsoUtc(
      history[endIdx].timestamp,
    );
    final visibleHistory = history.sublist(startIdx, endIdx + 1);
    final stats = _GlucoseRangeStats.fromHistory(
      visibleHistory,
      minMmol: widget.idealMinMmol,
      maxMmol: widget.idealMaxMmol,
    );

    final spots = <FlSpot>[];
    for (var i = startIdx; i <= endIdx; i++) {
      spots.add(
        FlSpot(
          i.toDouble(),
          glucoseDisplayValueFromMmol(history[i].mmol, widget.unit),
        ),
      );
    }

    final minY = widget.unit == GlucoseUnit.mmol ? 2.0 : 36.0;
    final maxY = widget.unit == GlucoseUnit.mmol ? 22.0 : 396.0;
    final yInterval = widget.unit == GlucoseUnit.mmol ? 2.0 : 36.0;
    final idealMinY = glucoseDisplayValueFromMmol(
      widget.idealMinMmol,
      widget.unit,
    );
    final idealMaxY = glucoseDisplayValueFromMmol(
      widget.idealMaxMmol,
      widget.unit,
    );

    final pred = widget.prediction;
    final predSpots = <FlSpot>[];
    if (pred != null && pred.nextPoints.isNotEmpty) {
      final lastIdx = (history.length - 1).toDouble();
      final lastY = glucoseDisplayValueFromMmol(history.last.mmol, widget.unit);
      predSpots.add(FlSpot(lastIdx, lastY));
      for (var i = 0; i < pred.nextPoints.length; i++) {
        predSpots.add(
          FlSpot(
            lastIdx + (i + 1).toDouble(),
            glucoseDisplayValueFromMmol(pred.nextPoints[i].mmol, widget.unit),
          ),
        );
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                        y1: idealMinY,
                        y2: idealMaxY,
                        color: scheme.primary.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: scheme.onSurface.withValues(alpha: 0.10),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: yInterval,
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
                          final idx = value.round().clamp(
                            0,
                            history.length - 1,
                          );
                          final t = formatLocalTimeFromIsoUtc(
                            history[idx].timestamp,
                          );
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
                    getTouchLineStart: (barData, spotIndex) => maxY,
                    getTouchLineEnd: (barData, spotIndex) =>
                        barData.spots[spotIndex].y,
                    getTouchedSpotIndicator: (barData, spotIndexes) {
                      return spotIndexes
                          .map((spotIndex) {
                            final lineColor =
                                (barData.gradient?.colors.first ??
                                        barData.color ??
                                        scheme.primary)
                                    .withValues(alpha: 0.7);
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: lineColor,
                                strokeWidth: 1.5,
                                dashArray: const [5, 5],
                              ),
                              FlDotData(
                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,
                                    color: lineColor,
                                    strokeWidth: 2,
                                    strokeColor: scheme.surface,
                                  );
                                },
                              ),
                            );
                          })
                          .toList(growable: false);
                    },
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBorderRadius: BorderRadius.circular(14),
                      tooltipMargin: 8,
                      maxContentWidth: 160,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      showOnTopOfTheChartBoxArea: true,
                      getTooltipColor: (_) => scheme.surfaceContainerHighest
                          .withValues(alpha: 0.95),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots
                            .map((spot) {
                              final idx = spot.x.round().clamp(
                                0,
                                history.length - 1,
                              );
                              final entry = history[idx];
                              final time = formatLocalTimeFromIsoUtc(
                                entry.timestamp,
                              );
                              return LineTooltipItem(
                                '${formatGlucoseEntry(entry, widget.unit)} ${widget.unit.displayName}\n$time',
                                TextStyle(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              );
                            })
                            .toList(growable: false);
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
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: glucoseDisplayValueFromMmol(
                          widget.alarmMinMmol,
                          widget.unit,
                        ),
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
                          labelResolver: (_) => formatGlucoseMmol(
                            widget.alarmMinMmol,
                            widget.unit,
                          ),
                        ),
                      ),
                      HorizontalLine(
                        y: glucoseDisplayValueFromMmol(
                          widget.alarmMaxMmol,
                          widget.unit,
                        ),
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
                          labelResolver: (_) => formatGlucoseMmol(
                            widget.alarmMaxMmol,
                            widget.unit,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      final hidden = v.round().clamp(
                        0,
                        totalPoints - _minVisiblePoints,
                      );
                      setState(() {
                        _visiblePoints = (totalPoints - hidden).clamp(
                          _minVisiblePoints,
                          totalPoints,
                        );
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatTile(
                  label: 'In range',
                  value: _formatPercent(stats.inRangePercent),
                  color: scheme.primary,
                ),
                _StatTile(
                  label: 'Low',
                  value: _formatPercent(stats.lowPercent),
                  color: scheme.error,
                ),
                _StatTile(
                  label: 'High',
                  value: _formatPercent(stats.highPercent),
                  color: scheme.tertiary,
                ),
                _StatTile(
                  label: 'Very high',
                  value: _formatPercent(stats.veryHighPercent),
                  color: scheme.error,
                ),
                _StatTile(
                  label: 'Hypos',
                  value: stats.hypoCount.toString(),
                  color: scheme.error,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ideal zone ${formatGlucoseMmol(widget.idealMinMmol, widget.unit)}–${formatGlucoseMmol(widget.idealMaxMmol, widget.unit)} ${widget.unit.displayName}. Very high starts at ${formatGlucoseMmol(_veryHighMmol, widget.unit)} ${widget.unit.displayName}.',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
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

const double _veryHighMmol = 13.9;
const Duration _defaultReadingInterval = Duration(minutes: 5);
const Duration _maxReadingInterval = Duration(minutes: 15);
const Duration _hypoRecoveryPeriod = Duration(minutes: 15);

String _formatPercent(double value) => '${value.round()}%';

class _GlucoseRangeStats {
  const _GlucoseRangeStats({
    required this.inRangePercent,
    required this.lowPercent,
    required this.highPercent,
    required this.veryHighPercent,
    required this.hypoCount,
  });

  final double inRangePercent;
  final double lowPercent;
  final double highPercent;
  final double veryHighPercent;
  final int hypoCount;

  static _GlucoseRangeStats fromHistory(
    List<GlucoseEntry> history, {
    required double minMmol,
    required double maxMmol,
  }) {
    if (history.isEmpty) {
      return const _GlucoseRangeStats(
        inRangePercent: 0,
        lowPercent: 0,
        highPercent: 0,
        veryHighPercent: 0,
        hypoCount: 0,
      );
    }

    var inRangeSeconds = 0.0;
    var lowSeconds = 0.0;
    var highSeconds = 0.0;
    var veryHighSeconds = 0.0;
    for (var i = 0; i < history.length; i++) {
      final entry = history[i];
      final seconds = _entryDuration(history, i).inSeconds.toDouble();
      if (entry.mmol < minMmol) {
        lowSeconds += seconds;
      } else if (entry.mmol > _veryHighMmol) {
        veryHighSeconds += seconds;
      } else if (entry.mmol > maxMmol) {
        highSeconds += seconds;
      } else {
        inRangeSeconds += seconds;
      }
    }

    final total = inRangeSeconds + lowSeconds + highSeconds + veryHighSeconds;
    return _GlucoseRangeStats(
      inRangePercent: inRangeSeconds * 100 / total,
      lowPercent: lowSeconds * 100 / total,
      highPercent: highSeconds * 100 / total,
      veryHighPercent: veryHighSeconds * 100 / total,
      hypoCount: _countHypoEpisodes(history, minMmol: minMmol),
    );
  }
}

Duration _entryDuration(List<GlucoseEntry> history, int index) {
  final current = _entryTime(history[index], fallbackIndex: index);
  final next = index < history.length - 1
      ? _entryTime(history[index + 1], fallbackIndex: index + 1)
      : null;
  final previous = index > 0
      ? _entryTime(history[index - 1], fallbackIndex: index - 1)
      : null;
  final duration = next != null
      ? next.difference(current)
      : previous != null
      ? current.difference(previous)
      : _defaultReadingInterval;
  if (duration <= Duration.zero || duration > _maxReadingInterval) {
    return _defaultReadingInterval;
  }
  return duration;
}

DateTime _entryTime(GlucoseEntry entry, {required int fallbackIndex}) {
  return DateTime.tryParse(entry.timestamp)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(
        fallbackIndex * _defaultReadingInterval.inMilliseconds,
        isUtc: true,
      );
}

int _countHypoEpisodes(List<GlucoseEntry> history, {required double minMmol}) {
  var count = 0;
  var episodeOpen = false;
  DateTime? aboveSince;

  for (var i = 0; i < history.length; i++) {
    final entry = history[i];
    final at = _entryTime(entry, fallbackIndex: i);

    if (entry.mmol < minMmol) {
      if (!episodeOpen) {
        count++;
        episodeOpen = true;
      }
      aboveSince = null;
      continue;
    }

    if (episodeOpen) {
      aboveSince ??= at;
      if (at.difference(aboveSince) >= _hypoRecoveryPeriod) {
        episodeOpen = false;
        aboveSince = null;
      }
    }
  }

  return count;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 116,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.70),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
