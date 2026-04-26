import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import 'app/app_state.dart';
import 'app/background_monitor.dart';
import 'app/credentials.dart';
import 'app/theme.dart';
import 'screens/alarm_config_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await BackgroundMonitor.ensureInitialized();
  runApp(const DexcomFollowApp());
}

class DexcomFollowApp extends StatelessWidget {
  const DexcomFollowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(credentialStore: CredentialStore()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Teddycom',
        theme: buildAppTheme(),
        routes: {AlarmConfigScreen.routeName: (_) => const AlarmConfigScreen()},
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final state = context.read<AppState>();
    Future<void>(() async {
      await state.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return switch (state.phase) {
      AppPhase.initializing => const _SplashScreen(),
      AppPhase.loggedOut => const LoginScreen(),
      AppPhase.loggedIn => const HomeScreen(),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 30,
              width: 30,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            Text(
              'Connecting…',
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
