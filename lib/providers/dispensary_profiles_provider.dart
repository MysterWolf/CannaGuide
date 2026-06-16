import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../db/models/dispensary_profile.dart';

class DispensaryProfilesProvider extends ChangeNotifier {
  final Map<String, DispensaryProfile> _cache = {};

  DispensaryProfile? profileFor(String dispensaryId) => _cache[dispensaryId];

  Future<DispensaryProfile?> load(String dispensaryId) async {
    final p = await AppDatabase.getDispensaryProfile(dispensaryId);
    if (p != null) {
      _cache[dispensaryId] = p;
    } else {
      _cache.remove(dispensaryId);
    }
    notifyListeners();
    return _cache[dispensaryId];
  }

  Future<void> save(DispensaryProfile p) async {
    await AppDatabase.upsertDispensaryProfile(p);
    _cache[p.dispensaryId] = p;
    notifyListeners();
  }

  Future<void> delete(String dispensaryId) async {
    await AppDatabase.deleteDispensaryProfile(dispensaryId);
    _cache.remove(dispensaryId);
    notifyListeners();
  }
}
