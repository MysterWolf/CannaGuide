import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../db/models/dispensary.dart';

class DispensariesProvider extends ChangeNotifier {
  List<Dispensary> _dispensaries = [];
  bool _loading = false;

  List<Dispensary> get dispensaries => _dispensaries;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _dispensaries = await AppDatabase.getDispensaries();
    _loading = false;
    notifyListeners();
  }

  Future<void> add(Dispensary d) async {
    await AppDatabase.insertDispensary(d);
    await load();
  }

  Future<void> update(Dispensary d) async {
    await AppDatabase.updateDispensary(d);
    await load();
  }

  Future<void> delete(String id) async {
    await AppDatabase.deleteDispensary(id);
    await load();
  }
}
