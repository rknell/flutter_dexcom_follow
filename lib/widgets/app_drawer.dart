import 'package:flutter/material.dart';

import '../screens/settings_screens.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withValues(alpha: 0.35),
                    scheme.secondary.withValues(alpha: 0.15),
                  ],
                ),
              ),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/icon/icon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Teddycom',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1.5),
                          blurRadius: 3,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Glucose'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Alarms'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(AlarmSettingsScreen.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Monitoring'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).pushNamed(BackgroundSettingsScreen.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_graph),
              title: const Text('Prediction'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).pushNamed(PredictionSettingsScreen.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Units'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).pushNamed(DisplaySettingsScreen.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Account'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(
                  context,
                ).pushNamed(AccountSettingsScreen.routeName);
              },
            ),
          ],
        ),
      ),
    );
  }
}
