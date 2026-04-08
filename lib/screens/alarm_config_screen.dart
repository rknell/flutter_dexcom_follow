import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../app/alarm_logic.dart' show kCriticalLowMmol;
import '../app/app_state.dart';
import '../app/background_monitor.dart';

class AlarmConfigScreen extends StatefulWidget {
  const AlarmConfigScreen({super.key});

  static const routeName = '/alarm';

  @override
  State<AlarmConfigScreen> createState() => _AlarmConfigScreenState();
}

class _AlarmConfigScreenState extends State<AlarmConfigScreen> {
  double? _min;
  double? _max;
  double? _staleAfter;
  bool _serviceBusy = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.alarmSettings;
    final scheme = Theme.of(context).colorScheme;

    final min = _min ?? settings.minMmol;
    final max = _max ?? settings.maxMmol;
    final staleAfter = _staleAfter ?? settings.staleAfterMinutes.toDouble();

    final invalid = min >= max;

    return Scaffold(
      appBar: AppBar(title: const Text('Alarm configuration')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                FutureBuilder<bool>(
                  future: BackgroundMonitor.isRunning(),
                  builder: (context, snap) {
                    final running = snap.data ?? false;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Background monitoring (Android)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              running
                                  ? 'Running as a foreground service (persistent notification). Restarts after reboot while you stay signed in.'
                                  : 'Off. Turn this on to alarm when the app is closed. Monitoring also starts automatically when you sign in (saved login).',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _serviceBusy
                                  ? null
                                  : () async {
                                      setState(() => _serviceBusy = true);
                                      try {
                                        await BackgroundMonitor.ensureInitialized();
                                        if (running) {
                                          await BackgroundMonitor.setUserPaused(true);
                                          await BackgroundMonitor.stop();
                                        } else {
                                          await BackgroundMonitor.setUserPaused(false);
                                          final result = await BackgroundMonitor.start();
                                          if (context.mounted &&
                                              result is ServiceRequestFailure) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Could not start monitoring: ${result.error}',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                        if (context.mounted) {
                                          setState(() {});
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setState(() => _serviceBusy = false);
                                        }
                                      }
                                    },
                              icon: Icon(running ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                              label: Text(running ? 'Stop monitoring' : 'Start monitoring'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Critical low safety alarm',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Readings at or below ${kCriticalLowMmol.toStringAsFixed(1)} mmol/L always '
                          'play an urgent alarm sound. This cannot be turned off and is separate from '
                          'the range settings below.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Alarm enabled',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Switch(
                              value: settings.enabled,
                              onChanged: (v) => state.updateAlarmSettings(
                                settings.copyWith(enabled: v),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'When enabled, the alarm plays every minute while glucose is out of range.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: !settings.enabled ? null : () => state.testAlarm(),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Test alarm'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Range',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Low alarm at or below: ${min.toStringAsFixed(1)} mmol/L',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: min.clamp(1.5, 10.0),
                          min: 1.5,
                          max: 10.0,
                          divisions: 85,
                          label: min.toStringAsFixed(1),
                          onChanged: (v) => setState(() => _min = double.parse(v.toStringAsFixed(1))),
                          onChangeEnd: (v) async {
                            final next = settings.copyWith(minMmol: double.parse(v.toStringAsFixed(1)));
                            await state.updateAlarmSettings(next);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'High alarm at or above: ${max.toStringAsFixed(1)} mmol/L',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: max.clamp(6.0, 25.0),
                          min: 6.0,
                          max: 25.0,
                          divisions: 190,
                          label: max.toStringAsFixed(1),
                          onChanged: (v) => setState(() => _max = double.parse(v.toStringAsFixed(1))),
                          onChangeEnd: (v) async {
                            final next = settings.copyWith(maxMmol: double.parse(v.toStringAsFixed(1)));
                            await state.updateAlarmSettings(next);
                          },
                        ),
                        if (invalid) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Min must be lower than max.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Out of sync (stale data)',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Switch(
                              value: settings.staleAlarmEnabled,
                              onChanged: (v) => state.updateAlarmSettings(
                                settings.copyWith(staleAlarmEnabled: v),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Triggers when no new reading arrives for more than ${settings.staleAfterMinutes} minutes.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Stale after: ${staleAfter.round()} minutes',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: staleAfter.clamp(5, 60),
                          min: 5,
                          max: 60,
                          divisions: 55,
                          label: staleAfter.round().toString(),
                          onChanged: (v) => setState(() => _staleAfter = v),
                          onChangeEnd: (v) async {
                            await state.updateAlarmSettings(
                              settings.copyWith(staleAfterMinutes: v.round()),
                            );
                          },
                        ),
                      ],
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

