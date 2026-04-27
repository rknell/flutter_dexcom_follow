import 'package:dexcom_share_api/dexcom_share_api.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/alarm_logic.dart' show isDataStale, kCriticalLowMmol;
import '../app/alarm_settings.dart';
import '../app/app_state.dart';
import '../app/background_monitor.dart';
import '../app/dexcom_repository.dart';
import '../app/glucose_format.dart';
import '../app/prediction.dart';
import '../screens/settings_screens.dart';
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
                  settings: state.alarmSettings,
                ),
                const SizedBox(height: 12),
                _PredictionCard(
                  prediction: state.prediction,
                  unit: state.alarmSettings.glucoseUnit,
                  algorithm: state.alarmSettings.predictionAlgorithm,
                  onTap: () => _showPredictionMethodPicker(context, state),
                ),
                const _MonitoringWarningSection(),
                GlucoseHistoryChart(
                  history: state.history,
                  prediction: state.prediction,
                  alarmMinMmol: state.alarmSettings.minMmol,
                  alarmMaxMmol: state.alarmSettings.maxMmol,
                  idealMinMmol: state.alarmSettings.idealMinMmol,
                  idealMaxMmol: state.alarmSettings.idealMaxMmol,
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
  const _HeroGlucoseCard({required this.snapshot, required this.settings});

  final GlucoseSnapshot? snapshot;
  final AlarmSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = settings.glucoseUnit;
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
    final readingTimeUtc = DateTime.tryParse(entry.timestamp)?.toUtc();
    final nowUtc = DateTime.now().toUtc();
    final age = readingTimeUtc == null
        ? null
        : nowUtc.difference(readingTimeUtc);
    final isStale = readingTimeUtc == null
        ? false
        : isDataStale(
            now: nowUtc,
            readingTimeUtc: readingTimeUtc,
            staleAfter: Duration(minutes: settings.staleAfterMinutes),
          );
    final status = _GlucoseDisplayStatus.fromMmol(
      mmol,
      minMmol: settings.minMmol,
      maxMmol: settings.maxMmol,
      isStale: isStale,
    );
    final pillColor = switch (status) {
      _GlucoseDisplayStatus.critical => scheme.error,
      _GlucoseDisplayStatus.low => scheme.error,
      _GlucoseDisplayStatus.high => scheme.tertiary,
      _GlucoseDisplayStatus.stale => scheme.outline,
      _GlucoseDisplayStatus.ok => scheme.primary,
    };

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
                    status.label,
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
              'Time: ${formatLocalTimeFromIsoUtc(entry.timestamp)}${age == null ? '' : ' (${_formatAge(age)} ago)'}',
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
  const _PredictionCard({
    required this.prediction,
    required this.unit,
    required this.algorithm,
    required this.onTap,
  });

  final PredictionResult? prediction;
  final GlucoseUnit unit;
  final PredictionAlgorithm algorithm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = prediction;
    if (p == null || p.nextPoints.isEmpty) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Prediction unavailable until enough recent readings arrive',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.tune, color: scheme.onSurfaceVariant),
              ],
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '20-minute prediction',
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
                      '${algorithm.shortName} • $trend (${slope.toStringAsFixed(2)} mmol/min)',
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
      ),
    );
  }
}

class _MonitoringWarningSection extends StatelessWidget {
  const _MonitoringWarningSection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<BackgroundMonitorStatus>(
      future: BackgroundMonitor.status(),
      builder: (context, snap) {
        final status = snap.data;
        if (status == null || status.isReady) {
          return const SizedBox(height: 12);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(
                context,
              ).pushNamed(BackgroundSettingsScreen.routeName),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.shield_moon_outlined, color: scheme.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _monitoringIssueText(status),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

enum _GlucoseDisplayStatus {
  critical('CRITICAL'),
  low('LOW'),
  high('HIGH'),
  stale('STALE'),
  ok('OK');

  const _GlucoseDisplayStatus(this.label);

  final String label;

  static _GlucoseDisplayStatus fromMmol(
    double mmol, {
    required double minMmol,
    required double maxMmol,
    required bool isStale,
  }) {
    if (mmol <= kCriticalLowMmol) return _GlucoseDisplayStatus.critical;
    if (isStale) return _GlucoseDisplayStatus.stale;
    if (mmol <= minMmol) return _GlucoseDisplayStatus.low;
    if (mmol >= maxMmol) return _GlucoseDisplayStatus.high;
    return _GlucoseDisplayStatus.ok;
  }
}

String _formatAge(Duration age) {
  final clean = age.isNegative ? Duration.zero : age;
  if (clean.inMinutes < 1) return 'just now';
  if (clean.inHours < 1) return '${clean.inMinutes} min';
  return '${clean.inHours} h ${clean.inMinutes.remainder(60)} min';
}

String _monitoringIssueText(BackgroundMonitorStatus status) {
  if (!status.hasSavedLogin) return 'Save login to enable background alarms';
  if (status.userPaused || !status.running) {
    return 'Background monitoring stopped';
  }
  if (!status.notificationPermissionGranted) {
    return 'Notifications must be allowed for background alarms';
  }
  if (!status.ignoringBatteryOptimizations) {
    return 'Set battery use to unrestricted for reliable monitoring';
  }
  return 'Background monitoring needs attention';
}

Future<void> _showPredictionMethodPicker(
  BuildContext context,
  AppState state,
) async {
  final selected = await showModalBottomSheet<PredictionAlgorithm>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final current = state.alarmSettings.predictionAlgorithm;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Prediction method',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final algorithm in PredictionAlgorithm.values)
              ListTile(
                title: Text(algorithm.displayName),
                trailing: algorithm == current
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(algorithm),
              ),
          ],
        ),
      );
    },
  );
  if (selected == null || !context.mounted) return;
  await state.updateAlarmSettings(
    state.alarmSettings.copyWith(predictionAlgorithm: selected),
  );
}
