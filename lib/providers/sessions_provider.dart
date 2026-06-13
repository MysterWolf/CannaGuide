import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../db/models/session.dart';

class SessionsProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _diary = [];
  bool _loading = false;

  List<Map<String, dynamic>> get diary => _diary;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _diary = await AppDatabase.getDiaryRows();
    _loading = false;
    notifyListeners();
  }

  Future<void> add(Session s) async {
    await AppDatabase.insertSession(s);
    await load();
  }
}
