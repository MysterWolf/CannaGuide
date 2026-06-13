import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/circles_provider.dart';
import 'providers/dispensaries_provider.dart';
import 'providers/sessions_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/strains_provider.dart';
import 'router/router.dart';
import 'theme/colors.dart';

class CannaGuideApp extends StatelessWidget {
  const CannaGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => SessionsProvider()),
        ChangeNotifierProvider(create: (_) => StrainsProvider()),
        ChangeNotifierProvider(create: (_) => DispensariesProvider()),
        ChangeNotifierProvider(create: (_) => CirclesProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp.router(
          title: 'CannaGuide',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: settings.themeMode,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
