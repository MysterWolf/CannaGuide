class Strain {
  final String id;
  final String name;
  final String? brand;
  final String? strainType;
  final double? thcPct;
  final double? cbdPct;
  final String? terpeneProfile;
  final String? cannabinoidProfile;
  final String? description;
  final String? source;
  final String? sourceType;
  final String? createdAt;
  final String? updatedAt;
  final String? category;
  final String? notes;
  final String? dispensaryId;

  const Strain({
    required this.id,
    required this.name,
    this.brand,
    this.strainType,
    this.thcPct,
    this.cbdPct,
    this.terpeneProfile,
    this.cannabinoidProfile,
    this.description,
    this.source,
    this.sourceType,
    this.createdAt,
    this.updatedAt,
    this.category,
    this.notes,
    this.dispensaryId,
  });

  Strain copyWith({
    String? name,
    String? brand,
    String? strainType,
    double? thcPct,
    double? cbdPct,
    String? terpeneProfile,
    String? description,
    String? category,
    String? notes,
    String? dispensaryId,
    String? updatedAt,
    bool clearBrand = false,
    bool clearNotes = false,
    bool clearDispensaryId = false,
  }) => Strain(
    id: id,
    name: name ?? this.name,
    brand: clearBrand ? null : (brand ?? this.brand),
    strainType: strainType ?? this.strainType,
    thcPct: thcPct ?? this.thcPct,
    cbdPct: cbdPct ?? this.cbdPct,
    terpeneProfile: terpeneProfile ?? this.terpeneProfile,
    cannabinoidProfile: cannabinoidProfile,
    description: description ?? this.description,
    source: source,
    sourceType: sourceType,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    category: category ?? this.category,
    notes: clearNotes ? null : (notes ?? this.notes),
    dispensaryId: clearDispensaryId ? null : (dispensaryId ?? this.dispensaryId),
  );

  factory Strain.fromMap(Map<String, dynamic> m) => Strain(
        id: m['id'] as String,
        name: m['name'] as String,
        brand: m['brand'] as String?,
        strainType: m['strain_type'] as String?,
        thcPct: (m['thc_pct'] as num?)?.toDouble(),
        cbdPct: (m['cbd_pct'] as num?)?.toDouble(),
        terpeneProfile: m['terpene_profile'] as String?,
        cannabinoidProfile: m['cannabinoid_profile'] as String?,
        description: m['description'] as String?,
        source: m['source'] as String?,
        sourceType: m['source_type'] as String?,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
        category: m['category'] as String?,
        notes: m['notes'] as String?,
        dispensaryId: m['dispensary_id'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'strain_type': strainType,
        'thc_pct': thcPct,
        'cbd_pct': cbdPct,
        'terpene_profile': terpeneProfile,
        'cannabinoid_profile': cannabinoidProfile,
        'description': description,
        'source': source,
        'source_type': sourceType,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'category': category,
        'notes': notes,
        'dispensary_id': dispensaryId,
      };
}
