import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../app/alarm_logic.dart' show kCriticalLowMmol;
import '../app/alarm_settings.dart';
import '../app/app_state.dart';
import '../app/background_monitor.dart';
import '../app/credentials.dart';
import '../app/glucose_format.dart';
import '../app/prediction.dart';

class BackgroundSettingsScreen extends StatefulWidget {
  const BackgroundSettingsScreen({super.key});

  static const routeName = '/settings/background';

  @override
  State<BackgroundSettingsScreen> createState() =>
      _BackgroundSettingsScreenState();
}

class _BackgroundSettingsScreenState extends State<BackgroundSettingsScreen> {
  bool _serviceBusy = false;

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Monitoring',
      children: [
        FutureBuilder<(bool, SavedCredentials?)>(
          future: () async {
            final running = await BackgroundMonitor.isRunning();
            final saved = await CredentialStore().read();
            return (running, saved);
          }(),
          builder: (context, snap) {
            final running = snap.data?.$1 ?? false;
            final saved = snap.data?.$2;
            final canStart = saved != null;
            return _SettingsCard(
              title: 'Background monitoring',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    running
                        ? 'Running as an Android foreground service. It waits for Dexcom\'s usual five-minute cadence, then probes every 30 seconds until a new reading arrives.'
                        : canStart
                        ? 'Stopped. Start monitoring to keep alarms active when the app is closed.'
                        : 'Saved login is required before background monitoring can run after the app closes.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _serviceBusy || (!running && !canStart)
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
                              if (context.mounted) setState(() {});
                            } finally {
                              if (context.mounted) {
                                setState(() => _serviceBusy = false);
                              }
                            }
                          },
                    icon: Icon(
                      running
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                    ),
                    label: Text(
                      running ? 'Stop monitoring' : 'Start monitoring',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class AlarmSettingsScreen extends StatefulWidget {
  const AlarmSettingsScreen({super.key});

  static const routeName = '/settings/alarms';

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  double? _min;
  double? _max;
  double? _staleAfter;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.alarmSettings;
    final unit = settings.glucoseUnit;
    final min = _min ?? settings.minMmol;
    final max = _max ?? settings.maxMmol;
    final staleAfter = _staleAfter ?? settings.staleAfterMinutes.toDouble();

    return _SettingsScaffold(
      title: 'Alarms',
      children: [
        _SettingsCard(
          title: 'Critical low safety alarm',
          tone: _SettingsCardTone.warning,
          child: Text(
            'Readings at or below ${formatGlucoseMmol(kCriticalLowMmol, unit)} ${unit.displayName} always play an urgent alarm. This cannot be turned off.',
          ),
        ),
        _SettingsCard(
          title: 'Standard range alarms',
          trailing: Switch(
            value: settings.enabled,
            onChanged: (v) =>
                state.updateAlarmSettings(settings.copyWith(enabled: v)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Repeats no more than once per minute while out of range.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: !settings.enabled ? null : () => state.testAlarm(),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Test alarm'),
              ),
              const Divider(height: 28),
              _ThresholdControl(
                label: 'Low alarm',
                valueMmol: min,
                minMmol: 1.5,
                maxMmol: (max - 0.1).clamp(1.5, 10.0).toDouble(),
                unit: unit,
                onChanged: (v) => setState(() => _min = v),
                onSubmitted: (v) {
                  final next = v.clamp(1.5, max - 0.1).toDouble();
                  state.updateAlarmSettings(
                    settings.copyWith(
                      minMmol: next,
                      predictionAlarmMmol: settings.predictionAlarmMmol
                          .clamp(1.5, next)
                          .toDouble(),
                    ),
                  );
                  setState(() => _min = next);
                },
              ),
              _ThresholdControl(
                label: 'High alarm',
                valueMmol: max,
                minMmol: (min + 0.1).clamp(6.0, 25.0).toDouble(),
                maxMmol: 25.0,
                unit: unit,
                onChanged: (v) => setState(() => _max = v),
                onSubmitted: (v) {
                  final next = v.clamp(min + 0.1, 25.0).toDouble();
                  state.updateAlarmSettings(settings.copyWith(maxMmol: next));
                  setState(() => _max = next);
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final defaults = AlarmSettingsStore.defaults;
                    state.updateAlarmSettings(
                      settings.copyWith(
                        minMmol: defaults.minMmol,
                        maxMmol: defaults.maxMmol,
                      ),
                    );
                    setState(() {
                      _min = defaults.minMmol;
                      _max = defaults.maxMmol;
                    });
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset range defaults'),
                ),
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: 'Out of sync',
          trailing: Switch(
            value: settings.staleAlarmEnabled,
            onChanged: (v) => state.updateAlarmSettings(
              settings.copyWith(staleAlarmEnabled: v),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Triggers when no new reading arrives for more than ${staleAfter.round()} minutes.',
              ),
              Slider(
                value: staleAfter.clamp(5, 60),
                min: 5,
                max: 60,
                divisions: 55,
                label: staleAfter.round().toString(),
                onChanged: (v) => setState(() => _staleAfter = v),
                onChangeEnd: (v) => state.updateAlarmSettings(
                  settings.copyWith(staleAfterMinutes: v.round()),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    state.updateAlarmSettings(
                      settings.copyWith(
                        staleAlarmEnabled:
                            AlarmSettingsStore.defaults.staleAlarmEnabled,
                        staleAfterMinutes:
                            AlarmSettingsStore.defaults.staleAfterMinutes,
                      ),
                    );
                    setState(
                      () => _staleAfter = AlarmSettingsStore
                          .defaults
                          .staleAfterMinutes
                          .toDouble(),
                    );
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset stale defaults'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PredictionSettingsScreen extends StatefulWidget {
  const PredictionSettingsScreen({super.key});

  static const routeName = '/settings/prediction';

  @override
  State<PredictionSettingsScreen> createState() =>
      _PredictionSettingsScreenState();
}

class _PredictionSettingsScreenState extends State<PredictionSettingsScreen> {
  double? _predictionAlarmMmol;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.alarmSettings;
    final unit = settings.glucoseUnit;
    final predictionAlarmMmol =
        _predictionAlarmMmol ?? settings.predictionAlarmMmol;

    return _SettingsScaffold(
      title: 'Prediction',
      children: [
        _SettingsCard(
          title: 'Forecast',
          child: DropdownButtonFormField<PredictionAlgorithm>(
            initialValue: settings.predictionAlgorithm,
            decoration: const InputDecoration(
              labelText: 'Algorithm',
              border: OutlineInputBorder(),
            ),
            items: PredictionAlgorithm.values
                .map(
                  (algorithm) => DropdownMenuItem(
                    value: algorithm,
                    child: Text(algorithm.displayName),
                  ),
                )
                .toList(growable: false),
            onChanged: (algorithm) {
              if (algorithm == null) return;
              state.updateAlarmSettings(
                settings.copyWith(predictionAlgorithm: algorithm),
              );
            },
          ),
        ),
        _SettingsCard(
          title: 'Predicted low alarm',
          trailing: Switch(
            value: settings.predictionAlarmEnabled,
            onChanged: (v) => state.updateAlarmSettings(
              settings.copyWith(predictionAlarmEnabled: v),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Uses only good-quality recent data. Critical current-low alarms still always run.',
              ),
              const SizedBox(height: 12),
              _ThresholdControl(
                label: 'Predicted low cutoff',
                valueMmol: predictionAlarmMmol,
                minMmol: 1.5,
                maxMmol: settings.minMmol,
                unit: unit,
                onChanged: (v) => setState(() => _predictionAlarmMmol = v),
                onSubmitted: (v) {
                  final next = v.clamp(1.5, settings.minMmol).toDouble();
                  state.updateAlarmSettings(
                    settings.copyWith(predictionAlarmMmol: next),
                  );
                  setState(() => _predictionAlarmMmol = next);
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    state.updateAlarmSettings(
                      settings.copyWith(
                        predictionAlgorithm:
                            AlarmSettingsStore.defaults.predictionAlgorithm,
                        predictionAlarmEnabled:
                            AlarmSettingsStore.defaults.predictionAlarmEnabled,
                        predictionAlarmMmol:
                            AlarmSettingsStore.defaults.predictionAlarmMmol,
                      ),
                    );
                    setState(
                      () => _predictionAlarmMmol =
                          AlarmSettingsStore.defaults.predictionAlarmMmol,
                    );
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset prediction defaults'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DisplaySettingsScreen extends StatelessWidget {
  const DisplaySettingsScreen({super.key});

  static const routeName = '/settings/display';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.alarmSettings;

    return _SettingsScaffold(
      title: 'Units',
      children: [
        _SettingsCard(
          title: 'Glucose units',
          child: SegmentedButton<GlucoseUnit>(
            segments: GlucoseUnit.values
                .map(
                  (unit) =>
                      ButtonSegment(value: unit, label: Text(unit.displayName)),
                )
                .toList(growable: false),
            selected: {settings.glucoseUnit},
            onSelectionChanged: (selected) {
              state.updateAlarmSettings(
                settings.copyWith(glucoseUnit: selected.single),
              );
            },
          ),
        ),
        const _SettingsCard(
          title: 'History and chart',
          child: Text(
            'The app keeps the chart fixed to the available Dexcom Share window: up to 24 hours and 288 readings.',
          ),
        ),
      ],
    );
  }
}

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  static const routeName = '/settings/account';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.alarmSettings;

    return _SettingsScaffold(
      title: 'Account',
      children: [
        _SettingsCard(
          title: 'Dexcom Share',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(state.username.isEmpty ? 'Signed in' : state.username),
              const SizedBox(height: 12),
              DropdownButtonFormField<DexcomShareServer>(
                initialValue: settings.server,
                decoration: const InputDecoration(
                  labelText: 'Server',
                  border: OutlineInputBorder(),
                ),
                items: DexcomShareServer.values
                    .map(
                      (server) => DropdownMenuItem(
                        value: server,
                        child: Text(server.displayName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (server) {
                  if (server == null) return;
                  state.updateAlarmSettings(settings.copyWith(server: server));
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Changing server applies the next time you sign in. Saved login is stored locally and is required for background monitoring.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => state.logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => state.logout(clearSaved: true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Log out and clear saved login'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView.separated(
              padding: const EdgeInsets.all(18),
              itemBuilder: (context, index) => children[index],
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: children.length,
            ),
          ),
        ),
      ),
    );
  }
}

enum _SettingsCardTone { normal, warning }

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    this.trailing,
    this.tone = _SettingsCardTone.normal,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final _SettingsCardTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: tone == _SettingsCardTone.warning
          ? scheme.errorContainer.withValues(alpha: 0.35)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.78),
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdControl extends StatefulWidget {
  const _ThresholdControl({
    required this.label,
    required this.valueMmol,
    required this.minMmol,
    required this.maxMmol,
    required this.unit,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String label;
  final double valueMmol;
  final double minMmol;
  final double maxMmol;
  final GlucoseUnit unit;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onSubmitted;

  @override
  State<_ThresholdControl> createState() => _ThresholdControlState();
}

class _ThresholdControlState extends State<_ThresholdControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _displayValue);
  }

  @override
  void didUpdateWidget(_ThresholdControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _displayValue;
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _displayValue => formatGlucoseMmol(widget.valueMmol, widget.unit);

  double _fromDisplay(double value) {
    return switch (widget.unit) {
      GlucoseUnit.mmol => value,
      GlucoseUnit.mgdl => value / 18,
    };
  }

  @override
  Widget build(BuildContext context) {
    final divisions = ((widget.maxMmol - widget.minMmol) * 10).round().clamp(
      1,
      1000,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.label)),
            SizedBox(
              width: 112,
              child: TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  suffixText: widget.unit.displayName,
                  isDense: true,
                ),
                onSubmitted: (raw) {
                  final parsed = double.tryParse(raw.trim());
                  if (parsed == null) {
                    _controller.text = _displayValue;
                    return;
                  }
                  widget.onSubmitted(_fromDisplay(parsed));
                },
              ),
            ),
          ],
        ),
        Slider(
          value: widget.valueMmol.clamp(widget.minMmol, widget.maxMmol),
          min: widget.minMmol,
          max: widget.maxMmol,
          divisions: divisions,
          label:
              '${formatGlucoseMmol(widget.valueMmol, widget.unit)} ${widget.unit.displayName}',
          onChanged: (v) =>
              widget.onChanged(double.parse(v.toStringAsFixed(1))),
          onChangeEnd: (v) =>
              widget.onSubmitted(double.parse(v.toStringAsFixed(1))),
        ),
      ],
    );
  }
}
