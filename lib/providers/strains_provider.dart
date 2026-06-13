import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../db/models/strain.dart';

class StrainsProvider extends ChangeNotifier {
  List<Strain> _strains = [];
  bool _loading = false;

  List<Strain> get strains => _strains;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _strains = await AppDatabase.getStrains();
    _loading = false;
    notifyListeners();
  }

  Future<void> add(Strain s) async {
    await AppDatabase.insertStrain(s);
    await load();
  }
}
