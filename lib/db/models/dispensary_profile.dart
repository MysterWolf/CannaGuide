import 'dart:convert';

class DispensaryProfile {
  final String id;
  final String dispensaryId;
  final String? about;
  final String? hours; // JSON {"monday": "10am-8pm", ...}
  final String? website;
  final String? instagram;
  final String? leaflyUrl;
  final String? dutchieUrl;
  final String? otherOrderingUrl;
  final String? orderingPlatform;
  final String? paymentMethods; // JSON array of strings
  final int blackOwned;
  final int womanOwned;
  final int lgbtqFriendly;
  final int veteranOwned;
  final String? specials; // JSON array of {item, description, updated_at}
  final int? dateUpdated;
  final String? primaryColor;   // hex e.g. "#2C1A08"
  final String? secondaryColor;
  final String? backgroundColor;

  const DispensaryProfile({
    required this.id,
    required this.dispensaryId,
    this.about,
    this.hours,
    this.website,
    this.instagram,
    this.leaflyUrl,
    this.dutchieUrl,
    this.otherOrderingUrl,
    this.orderingPlatform,
    this.paymentMethods,
    this.blackOwned = 0,
    this.womanOwned = 0,
    this.lgbtqFriendly = 0,
    this.veteranOwned = 0,
    this.specials,
    this.dateUpdated,
    this.primaryColor,
    this.secondaryColor,
    this.backgroundColor,
  });

  Map<String, String> get hoursMap {
    if (hours == null || hours!.isEmpty) return {};
    try { return Map<String, String>.from(jsonDecode(hours!)); } catch (_) { return {}; }
  }

  List<String> get paymentList {
    if (paymentMethods == null || paymentMethods!.isEmpty) return [];
    try { return List<String>.from(jsonDecode(paymentMethods!)); } catch (_) { return []; }
  }

  List<Map<String, dynamic>> get specialsList {
    if (specials == null || specials!.isEmpty) return [];
    try { return List<Map<String, dynamic>>.from(jsonDecode(specials!)); } catch (_) { return []; }
  }

  List<Map<String, dynamic>> get currentSpecials {
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    return specialsList.where((s) {
      final t = s['updated_at'] as int?;
      return t == null || t >= cutoff;
    }).toList();
  }

  bool get hasOwnershipBadges =>
      blackOwned == 1 || womanOwned == 1 || lgbtqFriendly == 1 || veteranOwned == 1;

  bool get hasLinks =>
      (website?.isNotEmpty ?? false) ||
      (instagram?.isNotEmpty ?? false) ||
      (leaflyUrl?.isNotEmpty ?? false) ||
      (dutchieUrl?.isNotEmpty ?? false) ||
      (otherOrderingUrl?.isNotEmpty ?? false);

  factory DispensaryProfile.fromMap(Map<String, dynamic> m) => DispensaryProfile(
        id: m['id'] as String,
        dispensaryId: m['dispensary_id'] as String,
        about: m['about'] as String?,
        hours: m['hours'] as String?,
        website: m['website'] as String?,
        instagram: m['instagram'] as String?,
        leaflyUrl: m['leafly_url'] as String?,
        dutchieUrl: m['dutchie_url'] as String?,
        otherOrderingUrl: m['other_ordering_url'] as String?,
        orderingPlatform: m['ordering_platform'] as String?,
        paymentMethods: m['payment_methods'] as String?,
        blackOwned: m['black_owned'] as int? ?? 0,
        womanOwned: m['woman_owned'] as int? ?? 0,
        lgbtqFriendly: m['lgbtq_friendly'] as int? ?? 0,
        veteranOwned: m['veteran_owned'] as int? ?? 0,
        specials: m['specials'] as String?,
        dateUpdated: m['date_updated'] as int?,
        primaryColor: m['primary_color'] as String?,
        secondaryColor: m['secondary_color'] as String?,
        backgroundColor: m['background_color'] as String?,
      );

  // Used when reconstructing from a Circle share on the recipient's device.
  factory DispensaryProfile.fromSharePayload(
      String id, String dispensaryId, Map<String, dynamic> p) =>
      DispensaryProfile(
        id: id,
        dispensaryId: dispensaryId,
        about: p['about'] as String?,
        hours: p['hours'] as String?,
        website: p['website'] as String?,
        instagram: p['instagram'] as String?,
        leaflyUrl: p['leafly_url'] as String?,
        dutchieUrl: p['dutchie_url'] as String?,
        otherOrderingUrl: p['other_ordering_url'] as String?,
        orderingPlatform: p['ordering_platform'] as String?,
        paymentMethods: p['payment_methods'] as String?,
        blackOwned: p['black_owned'] as int? ?? 0,
        womanOwned: p['woman_owned'] as int? ?? 0,
        lgbtqFriendly: p['lgbtq_friendly'] as int? ?? 0,
        veteranOwned: p['veteran_owned'] as int? ?? 0,
        specials: p['specials'] as String?,
        dateUpdated: DateTime.now().millisecondsSinceEpoch,
        primaryColor: p['primary_color'] as String?,
        secondaryColor: p['secondary_color'] as String?,
        backgroundColor: p['background_color'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'dispensary_id': dispensaryId,
        'about': about,
        'hours': hours,
        'website': website,
        'instagram': instagram,
        'leafly_url': leaflyUrl,
        'dutchie_url': dutchieUrl,
        'other_ordering_url': otherOrderingUrl,
        'ordering_platform': orderingPlatform,
        'payment_methods': paymentMethods,
        'black_owned': blackOwned,
        'woman_owned': womanOwned,
        'lgbtq_friendly': lgbtqFriendly,
        'veteran_owned': veteranOwned,
        'specials': specials,
        'date_updated': dateUpdated,
        'primary_color': primaryColor,
        'secondary_color': secondaryColor,
        'background_color': backgroundColor,
      };

  // Strip id/dispensary_id so recipient can attach to their own local dispensary.
  Map<String, dynamic> toSharePayload() => {
        'about': about,
        'hours': hours,
        'website': website,
        'instagram': instagram,
        'leafly_url': leaflyUrl,
        'dutchie_url': dutchieUrl,
        'other_ordering_url': otherOrderingUrl,
        'ordering_platform': orderingPlatform,
        'payment_methods': paymentMethods,
        'black_owned': blackOwned,
        'woman_owned': womanOwned,
        'lgbtq_friendly': lgbtqFriendly,
        'veteran_owned': veteranOwned,
        'specials': specials,
      };
}
