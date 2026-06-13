import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'db/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Pre-open DB — copies backup from assets on first launch
  await AppDatabase.db;

  runApp(const CannaGuideApp());
}
