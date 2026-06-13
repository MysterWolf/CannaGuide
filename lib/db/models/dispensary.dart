class Dispensary {
  final String id;
  final String name;
  final String? city;
  final String? state;
  final String? apiSource;
  final String? externalId;
  final String? venueType;
  final int? vibeRating;
  final String? priceTier;
  final int? staffRating;
  final int? wouldGoBack;
  final String? createdAt;
  final String? stashpassOperatorId;

  const Dispensary({
    required this.id,
    required this.name,
    this.city,
    this.state,
    this.apiSource,
    this.externalId,
    this.venueType,
    this.vibeRating,
    this.priceTier,
    this.staffRating,
    this.wouldGoBack,
    this.createdAt,
    this.stashpassOperatorId,
  });

  factory Dispensary.fromMap(Map<String, dynamic> m) => Dispensary(
        id: m['id'] as String,
        name: m['name'] as String,
        city: m['city'] as String?,
        state: m['state'] as String?,
        apiSource: m['api_source'] as String?,
        externalId: m['external_id'] as String?,
        venueType: m['venue_type'] as String?,
        vibeRating: m['vibe_rating'] as int?,
        priceTier: m['price_tier'] as String?,
        staffRating: m['staff_rating'] as int?,
        wouldGoBack: m['would_go_back'] as int?,
        createdAt: m['created_at'] as String?,
        stashpassOperatorId: m['stashpass_operator_id'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'city': city,
        'state': state,
        'api_source': apiSource,
        'external_id': externalId,
        'venue_type': venueType,
        'vibe_rating': vibeRating,
        'price_tier': priceTier,
        'staff_rating': staffRating,
        'would_go_back': wouldGoBack,
        'created_at': createdAt,
        'stashpass_operator_id': stashpassOperatorId,
      };
}
