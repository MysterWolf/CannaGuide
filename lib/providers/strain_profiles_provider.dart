import 'package:flutter/foundation.dart';
import '../db/database.dart';
import '../db/models/strain_profile.dart';

class StrainProfilesProvider extends ChangeNotifier {
  final Map<String, StrainProfile> _cache = {};

  StrainProfile? profileFor(String strainId) => _cache[strainId];

  void clearCache() {
    _cache.clear();
    notifyListeners();
  }

  Future<StrainProfile?> load(String strainId) async {
    final p = await AppDatabase.getStrainProfile(strainId);
    if (p != null) {
      _cache[strainId] = p;
    } else {
      _cache.remove(strainId);
    }
    notifyListeners();
    return _cache[strainId];
  }

  Future<void> save(StrainProfile p) async {
    await AppDatabase.upsertStrainProfile(p);
    _cache[p.strainId] = p;
    notifyListeners();
  }

  Future<void> delete(String strainId) async {
    await AppDatabase.deleteStrainProfile(strainId);
    _cache.remove(strainId);
    notifyListeners();
  }
}
