class Session {
  final String id;
  final String? userId;
  final String? strainId;
  final String? dispensaryId;
  final String? method;
  final double? doseMg;
  final String? doseNotes;
  final String sessionAt;
  final String? timeOfDay;
  final String? setting;
  final int? effectFocus;
  final int? effectSleep;
  final int? effectAnxiety;
  final int? effectPain;
  final int? effectMood;
  final int? effectCreativity;
  final int? effectHunger;
  final int? effectEnergy;
  final int? overallRating;
  final int? durationMins;
  final int? onsetMins;
  final String? notes;
  final int? sideDryMouth;
  final int? sideParanoia;
  final int? sideHeadache;
  final int? sideAnxiety;
  final int? sideCouchLock;
  final String? couchLockIntent;
  final String? hungerIntent;
  final String? createdAt;
  final String? updatedAt;
  final String? productCategory;
  final double? mgThc;
  final double? mgCbd;
  final String? productType;
  final String? productFlavor;
  final String? functionalIngredients;
  final String? useCase;

  const Session({
    required this.id,
    this.userId,
    this.strainId,
    this.dispensaryId,
    this.method,
    this.doseMg,
    this.doseNotes,
    required this.sessionAt,
    this.timeOfDay,
    this.setting,
    this.effectFocus,
    this.effectSleep,
    this.effectAnxiety,
    this.effectPain,
    this.effectMood,
    this.effectCreativity,
    this.effectHunger,
    this.effectEnergy,
    this.overallRating,
    this.durationMins,
    this.onsetMins,
    this.notes,
    this.sideDryMouth,
    this.sideParanoia,
    this.sideHeadache,
    this.sideAnxiety,
    this.sideCouchLock,
    this.couchLockIntent,
    this.hungerIntent,
    this.createdAt,
    this.updatedAt,
    this.productCategory,
    this.mgThc,
    this.mgCbd,
    this.productType,
    this.productFlavor,
    this.functionalIngredients,
    this.useCase,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'strain_id': strainId,
        'dispensary_id': dispensaryId,
        'method': method,
        'dose_mg': doseMg,
        'dose_notes': doseNotes,
        'session_at': sessionAt,
        'time_of_day': timeOfDay,
        'setting': setting,
        'effect_focus': effectFocus,
        'effect_sleep': effectSleep,
        'effect_anxiety': effectAnxiety,
        'effect_pain': effectPain,
        'effect_mood': effectMood,
        'effect_creativity': effectCreativity,
        'effect_hunger': effectHunger,
        'effect_energy': effectEnergy,
        'overall_rating': overallRating,
        'duration_mins': durationMins,
        'onset_mins': onsetMins,
        'notes': notes,
        'side_dry_mouth': sideDryMouth,
        'side_paranoia': sideParanoia,
        'side_headache': sideHeadache,
        'side_anxiety': sideAnxiety,
        'side_couch_lock': sideCouchLock,
        'couch_lock_intent': couchLockIntent,
        'hunger_intent': hungerIntent,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'product_category': productCategory,
        'mg_thc': mgThc,
        'mg_cbd': mgCbd,
        'product_type': productType,
        'product_flavor': productFlavor,
        'functional_ingredients': functionalIngredients,
        'use_case': useCase,
      };

  factory Session.fromMap(Map<String, dynamic> m) => Session(
        id: m['id'] as String,
        userId: m['user_id'] as String?,
        strainId: m['strain_id'] as String?,
        dispensaryId: m['dispensary_id'] as String?,
        method: m['method'] as String?,
        doseMg: (m['dose_mg'] as num?)?.toDouble(),
        doseNotes: m['dose_notes'] as String?,
        sessionAt: m['session_at'] as String,
        timeOfDay: m['time_of_day'] as String?,
        setting: m['setting'] as String?,
        effectFocus: m['effect_focus'] as int?,
        effectSleep: m['effect_sleep'] as int?,
        effectAnxiety: m['effect_anxiety'] as int?,
        effectPain: m['effect_pain'] as int?,
        effectMood: m['effect_mood'] as int?,
        effectCreativity: m['effect_creativity'] as int?,
        effectHunger: m['effect_hunger'] as int?,
        effectEnergy: m['effect_energy'] as int?,
        overallRating: m['overall_rating'] as int?,
        durationMins: m['duration_mins'] as int?,
        onsetMins: m['onset_mins'] as int?,
        notes: m['notes'] as String?,
        sideDryMouth: m['side_dry_mouth'] as int?,
        sideParanoia: m['side_paranoia'] as int?,
        sideHeadache: m['side_headache'] as int?,
        sideAnxiety: m['side_anxiety'] as int?,
        sideCouchLock: m['side_couch_lock'] as int?,
        couchLockIntent: m['couch_lock_intent'] as String?,
        hungerIntent: m['hunger_intent'] as String?,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
        productCategory: m['product_category'] as String?,
        mgThc: (m['mg_thc'] as num?)?.toDouble(),
        mgCbd: (m['mg_cbd'] as num?)?.toDouble(),
        productType: m['product_type'] as String?,
        productFlavor: m['product_flavor'] as String?,
        functionalIngredients: m['functional_ingredients'] as String?,
        useCase: m['use_case'] as String?,
      );
}
