import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/alarm_settings.dart';
import '../app/app_state.dart';
import '../app/dexcom_repository.dart';
import '../app/glucose_format.dart';
import '../app/prediction.dart';
import '../widgets/app_drawer.dart';
import '../widgets/glucose_history_chart.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final snapshot = state.latest;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Teddycom'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.phase == AppPhase.loggedIn
                ? state.refreshNow
                : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _HeroGlucoseCard(
                  snapshot: snapshot,
                  unit: state.alarmSettings.glucoseUnit,
                ),
                const SizedBox(height: 12),
                _PredictionCard(
                  prediction: state.prediction,
                  unit: state.alarmSettings.glucoseUnit,
                ),
                const SizedBox(height: 12),
                GlucoseHistoryChart(
                  history: state.history,
                  prediction: state.prediction,
                  alarmMinMmol: state.alarmSettings.minMmol,
                  alarmMaxMmol: state.alarmSettings.maxMmol,
                  unit: state.alarmSettings.glucoseUnit,
                ),
                const SizedBox(height: 12),
                if (state.error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      state.error!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroGlucoseCard extends StatelessWidget {
  const _HeroGlucoseCard({required this.snapshot, required this.unit});

  final GlucoseSnapshot? snapshot;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (snapshot == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Fetching latest reading…',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    final entry = snapshot!.entry;
    final mmol = entry.mmol;
    final isLow = mmol <= 3.9;
    final pillColor = isLow ? scheme.error : scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Latest',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: pillColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    isLow ? 'LOW' : 'OK',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: pillColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatGlucoseEntry(entry, unit),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    unit.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TrendIcon(trend: entry.trend),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Time: ${formatLocalTimeFromIsoUtc(entry.timestamp)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction, required this.unit});

  final PredictionResult? prediction;
  final GlucoseUnit unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = prediction;
    if (p == null || p.nextPoints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Prediction: collecting enough data…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      );
    }

    final p20 = p.nextPoints.last;
    final slope = p.slopeMmolPerMinute;
    final trend = slope.abs() < 0.01
        ? 'steady'
        : slope > 0
        ? 'rising'
        : 'falling';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '20‑minute prediction',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${formatGlucoseMmol(p20.mmol, unit)} ${unit.displayName} in 20 min',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.80),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Method: ${p.algorithm.shortName} • Quality: ${p.quality.status.displayName} • Trend: $trend (${slope.toStringAsFixed(2)} mmol/min)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              slope.abs() < 0.01
                  ? Icons.horizontal_rule
                  : slope > 0
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: scheme.primary,
              size: 34,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendIcon extends StatelessWidget {
  const _TrendIcon({required this.trend});

  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (trend) {
      Trend.doubleup => Icons.keyboard_double_arrow_up,
      Trend.singleup => Icons.keyboard_arrow_up,
      Trend.fortyfiveup => Icons.north_east,
      Trend.flat => Icons.east,
      Trend.fortyfivedown => Icons.south_east,
      Trend.singledown => Icons.keyboard_arrow_down,
      Trend.doubledown => Icons.keyboard_double_arrow_down,
    };

    return Icon(
      icon,
      size: 38,
      color: scheme.onSurface.withValues(alpha: 0.85),
    );
  }
}
