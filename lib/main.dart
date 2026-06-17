import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'db/database.dart';
import 'providers/circles_provider.dart';
import 'providers/dispensaries_provider.dart';
import 'providers/dispensary_profiles_provider.dart';
import 'providers/sessions_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/strain_profiles_provider.dart';
import 'providers/strains_provider.dart';
import 'app.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Pre-open DB — copies backup from assets on first launch
  await AppDatabase.db;
  await NotificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => SessionsProvider()),
        ChangeNotifierProvider(create: (_) => StrainsProvider()),
        ChangeNotifierProvider(create: (_) => StrainProfilesProvider()),
        ChangeNotifierProvider(create: (_) => DispensariesProvider()),
        ChangeNotifierProvider(create: (_) => DispensaryProfilesProvider()),
        ChangeNotifierProvider(create: (_) => CirclesProvider()),
      ],
      child: const CannaGuideApp(),
    ),
  );
}
