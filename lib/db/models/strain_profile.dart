import 'dart:convert';

class StrainProfile {
  final String id;
  final String strainId;
  final String? aliases;        // JSON array of strings
  final String? lineage;
  final double? thcMin;
  final double? thcMax;
  final double? cbdMin;
  final double? cbdMax;
  final String? terpenes;       // JSON array of {name, effect}
  final String? primaryEffects; // JSON array of strings
  final String? useCases;       // JSON array of strings
  final String? flavorProfile;  // JSON array of strings
  final String? about;
  final String? cautions;
  final String? bestMethod;
  final int beginnerFriendly;
  final int? dateUpdated;

  const StrainProfile({
    required this.id,
    required this.strainId,
    this.aliases,
    this.lineage,
    this.thcMin,
    this.thcMax,
    this.cbdMin,
    this.cbdMax,
    this.terpenes,
    this.primaryEffects,
    this.useCases,
    this.flavorProfile,
    this.about,
    this.cautions,
    this.bestMethod,
    this.beginnerFriendly = 0,
    this.dateUpdated,
  });

  List<String> get aliasesList {
    if (aliases == null || aliases!.isEmpty) return [];
    try { return List<String>.from(jsonDecode(aliases!)); } catch (_) { return []; }
  }

  List<Map<String, dynamic>> get terpenesList {
    if (terpenes == null || terpenes!.isEmpty) return [];
    try { return List<Map<String, dynamic>>.from(jsonDecode(terpenes!)); } catch (_) { return []; }
  }

  List<String> get primaryEffectsList {
    if (primaryEffects == null || primaryEffects!.isEmpty) return [];
    try { return List<String>.from(jsonDecode(primaryEffects!)); } catch (_) { return []; }
  }

  List<String> get useCasesList {
    if (useCases == null || useCases!.isEmpty) return [];
    try { return List<String>.from(jsonDecode(useCases!)); } catch (_) { return []; }
  }

  List<String> get flavorList {
    if (flavorProfile == null || flavorProfile!.isEmpty) return [];
    try { return List<String>.from(jsonDecode(flavorProfile!)); } catch (_) { return []; }
  }

  bool get hasContent =>
      (about?.isNotEmpty ?? false) ||
      terpenesList.isNotEmpty ||
      primaryEffectsList.isNotEmpty ||
      useCasesList.isNotEmpty ||
      flavorList.isNotEmpty ||
      lineage != null ||
      thcMin != null ||
      thcMax != null;

  factory StrainProfile.fromMap(Map<String, dynamic> m) => StrainProfile(
        id: m['id'] as String,
        strainId: m['strain_id'] as String,
        aliases: m['aliases'] as String?,
        lineage: m['lineage'] as String?,
        thcMin: _parseDouble(m['thc_min']),
        thcMax: _parseDouble(m['thc_max']),
        cbdMin: _parseDouble(m['cbd_min']),
        cbdMax: _parseDouble(m['cbd_max']),
        terpenes: m['terpenes'] as String?,
        primaryEffects: m['primary_effects'] as String?,
        useCases: m['use_cases'] as String?,
        flavorProfile: m['flavor_profile'] as String?,
        about: m['about'] as String?,
        cautions: m['cautions'] as String?,
        bestMethod: m['best_method'] as String?,
        beginnerFriendly: m['beginner_friendly'] as int? ?? 0,
        dateUpdated: m['date_updated'] as int?,
      );

  static double? _parseDouble(Object? v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  Map<String, dynamic> toMap() => {
        'id': id,
        'strain_id': strainId,
        'aliases': aliases,
        'lineage': lineage,
        'thc_min': thcMin,
        'thc_max': thcMax,
        'cbd_min': cbdMin,
        'cbd_max': cbdMax,
        'terpenes': terpenes,
        'primary_effects': primaryEffects,
        'use_cases': useCases,
        'flavor_profile': flavorProfile,
        'about': about,
        'cautions': cautions,
        'best_method': bestMethod,
        'beginner_friendly': beginnerFriendly,
        'date_updated': dateUpdated,
      };
}
