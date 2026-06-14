import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/settings_provider.dart';
import 'router/router.dart';
import 'theme/colors.dart';

class CannaGuideApp extends StatelessWidget {
  const CannaGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => MaterialApp.router(
        title: 'CannaGuide',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: settings.themeMode,
        routerConfig: appRouter,
      ),
    );
  }
}
