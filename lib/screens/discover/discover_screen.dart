import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config.dart';
import '../../db/models/dispensary.dart';
import '../../db/models/dispensary_profile.dart';
import '../../db/models/strain.dart';
import '../../db/models/strain_profile.dart';
import '../../providers/dispensaries_provider.dart';
import '../../providers/dispensary_profiles_provider.dart';
import '../../providers/strain_profiles_provider.dart';
import '../../providers/strains_provider.dart';
import '../../theme/colors.dart';

const _venueLabels = {
  'dispensary': 'Dispensary',
  'wellness_retail': 'Wellness Retail',
  'smoke_shop': 'Smoke Shop',
  'liquor_store': 'Liquor Store',
  'general_retail': 'General Retail',
};

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  String? _strainTypeFilter;
  String? _venueTypeFilter;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StrainsProvider>().load();
      context.read<DispensariesProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: C.bg,
            floating: true,
            title: const Text('Discover', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 22)),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: C.accent,
              labelColor: C.accent,
              unselectedLabelColor: C.muted,
              tabs: const [
                Tab(text: 'Strains'),
                Tab(text: 'Dispensaries'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _StrainsTab(
              typeFilter: _strainTypeFilter,
              onTypeFilterChanged: (v) => setState(() => _strainTypeFilter = v),
            ),
            _DispensariesTab(
              venueFilter: _venueTypeFilter,
              onVenueFilterChanged: (v) => setState(() => _venueTypeFilter = v),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tabCtrl.index == 0
            ? context.push('/add-strain')
            : context.push('/add-dispensary'),
        label: Text(_tabCtrl.index == 0 ? 'Add Strain' : 'Add Dispensary'),
        icon: const Icon(Icons.add),
        backgroundColor: C.accent,
        foregroundColor: C.white,
      ),
    );
  }
}

class _StrainsTab extends StatefulWidget {
  final String? typeFilter;
  final ValueChanged<String?> onTypeFilterChanged;

  const _StrainsTab({required this.typeFilter, required this.onTypeFilterChanged});

  @override
  State<_StrainsTab> createState() => _StrainsTabState();
}

class _StrainsTabState extends State<_StrainsTab> {
  // Fire once per app lifecycle so the list refreshes from API on launch.
  static bool _hasAutoSynced = false;

  @override
  void initState() {
    super.initState();
    if (!_hasAutoSynced) {
      _hasAutoSynced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    context.read<StrainProfilesProvider>().clearCache();

    try {
      final res = await http
          .get(Uri.parse('$kCirclesApiBase/strains'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200 || !mounted) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final apiStrains = (data['strains'] as List?) ?? [];

      final strainsProvider = context.read<StrainsProvider>();

      // Snapshot local strains once; the provider reloads inside add/update
      // but we work off this snapshot to keep the loop deterministic.
      final allLocal = List<Strain>.from(strainsProvider.strains);
      final byStashpassId = <String, Strain>{
        for (final s in allLocal)
          if (s.stashpassStrainId != null) s.stashpassStrainId!: s,
      };
      final unlinked =
          allLocal.where((s) => s.stashpassStrainId == null).toList();
      final fuzzyClaimedIds = <String>{}; // local IDs linked this cycle
      int toastCount = 0;

      final profilesProvider = context.read<StrainProfilesProvider>();
      for (final st in apiStrains) {
        final stId = st['id'] as String?;
        if (stId == null) continue;

        final apiName = (st['name'] as String?) ?? '';
        final apiType = (st['type'] as String?) ?? '';

        Strain? strain = byStashpassId[stId];

        if (strain != null) {
          // STEP 1: linked row found — merge API-owned fields, leave user data untouched
          final newName = apiName.isNotEmpty ? apiName : strain.name;
          final newType = apiType.isNotEmpty ? apiType : strain.strainType;
          final changed = newName != strain.name || newType != strain.strainType;
          final updated = Strain(
            id: strain.id,
            name: newName,
            strainType: newType,
            brand: strain.brand,
            thcPct: strain.thcPct,
            cbdPct: strain.cbdPct,
            terpeneProfile: strain.terpeneProfile,
            cannabinoidProfile: strain.cannabinoidProfile,
            description: strain.description,
            source: strain.source,
            sourceType: strain.sourceType,
            createdAt: strain.createdAt,
            category: strain.category,
            notes: strain.notes,
            dispensaryId: strain.dispensaryId,
            stashpassStrainId: strain.stashpassStrainId,
          );
          await strainsProvider.update(updated);
          strain = updated;
          if (changed) toastCount++;
        } else {
          // STEP 2: no linked row — attempt one-time fuzzy match on unlinked rows.
          // Normalize: lowercase + trim + strip punctuation. Exact match only.
          final normalizedApiName = _normalizeName(apiName);
          Strain? matchedLocal;
          for (final s in unlinked) {
            if (!fuzzyClaimedIds.contains(s.id) &&
                _normalizeName(s.name) == normalizedApiName &&
                (s.strainType ?? '').toLowerCase() ==
                    apiType.toLowerCase()) {
              matchedLocal = s;
              break;
            }
          }

          if (matchedLocal != null) {
            // Fuzzy match found — establish link and merge
            fuzzyClaimedIds.add(matchedLocal.id);
            toastCount++;
            final linked = Strain(
              id: matchedLocal.id,
              name: apiName.isNotEmpty ? apiName : matchedLocal.name,
              strainType:
                  apiType.isNotEmpty ? apiType : matchedLocal.strainType,
              brand: matchedLocal.brand,
              thcPct: matchedLocal.thcPct,
              cbdPct: matchedLocal.cbdPct,
              terpeneProfile: matchedLocal.terpeneProfile,
              cannabinoidProfile: matchedLocal.cannabinoidProfile,
              description: matchedLocal.description,
              source: matchedLocal.source,
              sourceType: matchedLocal.sourceType,
              createdAt: matchedLocal.createdAt,
              category: matchedLocal.category,
              notes: matchedLocal.notes,
              dispensaryId: matchedLocal.dispensaryId,
              stashpassStrainId: stId,
            );
            await strainsProvider.update(linked);
            strain = linked;
          } else {
            // No local match — insert new row; user-owned fields start null/empty
            strain = Strain(
              id: const Uuid().v4(),
              name: apiName.isNotEmpty ? apiName : 'Unknown',
              strainType: apiType.isNotEmpty ? apiType : null,
              stashpassStrainId: stId,
              source: 'stashpass',
            );
            await strainsProvider.add(strain);
          }
        }

        await profilesProvider.save(_strainProfileFromApi(strain.id, st));
      }

      // STEP 3: toast if anything actually changed
      if (mounted && toastCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '$toastCount strain${toastCount == 1 ? '' : 's'} updated from StashPass'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      // Network or DB error — fall through to reload cached data
    }

    if (mounted) await context.read<StrainsProvider>().load();
  }

  // Normalize a strain name for fuzzy matching: lowercase, strip punctuation, collapse spaces.
  static String _normalizeName(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  StrainProfile _strainProfileFromApi(String strainId, Map<String, dynamic> p) {
    String? _encodeList(dynamic v) =>
        v == null ? null : jsonEncode(v);

    return StrainProfile(
      id: const Uuid().v4(),
      strainId: strainId,
      aliases: _encodeList(p['aliases']),
      lineage: p['lineage'] as String?,
      thcMin: _parseDouble(p['thc_min']),
      thcMax: _parseDouble(p['thc_max']),
      cbdMin: _parseDouble(p['cbd_min']),
      cbdMax: _parseDouble(p['cbd_max']),
      terpenes: _encodeList(p['terpenes']),
      primaryEffects: _encodeList(p['effects']),
      useCases: _encodeList(p['use_cases']),
      flavorProfile: _encodeList(p['flavors']),
      about: p['about'] as String?,
      cautions: p['cautions'] as String?,
      bestMethod: p['best_method'] as String?,
      beginnerFriendly:
          (p['beginner_friendly'] == true || p['beginner_friendly'] == 1) ? 1 : 0,
      dateUpdated: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static double? _parseDouble(Object? v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

  @override
  Widget build(BuildContext context) {
    return Consumer<StrainsProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator(color: C.accent));
        }

        final filtered = widget.typeFilter == null
            ? provider.strains
            : provider.strains
                .where((s) => s.strainType?.toLowerCase() == widget.typeFilter)
                .toList();

        return RefreshIndicator(
          color: C.accent,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: widget.typeFilter == null,
                        onTap: () => widget.onTypeFilterChanged(null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Sativa',
                        selected: widget.typeFilter == 'sativa',
                        color: C.sage,
                        onTap: () => widget.onTypeFilterChanged(
                            widget.typeFilter == 'sativa' ? null : 'sativa'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Hybrid',
                        selected: widget.typeFilter == 'hybrid',
                        color: C.amber,
                        onTap: () => widget.onTypeFilterChanged(
                            widget.typeFilter == 'hybrid' ? null : 'hybrid'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Indica',
                        selected: widget.typeFilter == 'indica',
                        color: C.danger,
                        onTap: () => widget.onTypeFilterChanged(
                            widget.typeFilter == 'indica' ? null : 'indica'),
                      ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                      child: Text('No strains yet',
                          style: TextStyle(color: C.muted))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _StrainCard(strain: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DispensariesTab extends StatefulWidget {
  final String? venueFilter;
  final ValueChanged<String?> onVenueFilterChanged;

  const _DispensariesTab({required this.venueFilter, required this.onVenueFilterChanged});

  @override
  State<_DispensariesTab> createState() => _DispensariesTabState();
}

class _DispensariesTabState extends State<_DispensariesTab> {
  static const _fallbackLat = 40.744;
  static const _fallbackLng = -74.032;
  static const _radiusKm = 80.0;

  Future<void> _refresh() async {
    // 1 — Clear the in-memory operator profile cache
    if (!mounted) return;
    context.read<DispensaryProfilesProvider>().clearCache();

    // 2 — Get device location; fall back to Hoboken if unavailable
    double lat = _fallbackLat, lng = _fallbackLng;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      }
    } catch (_) {
      // use fallback coordinates
    }

    // 3 — Fetch nearby operators from StashPass API
    try {
      final res = await http.get(Uri.parse(
        '$kCirclesApiBase/operators/nearby?lat=$lat&lng=$lng&radius=$_radiusKm',
      )).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200 || !mounted) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final operators = (data['operators'] as List?) ?? [];
      print('[sync] fetched ${operators.length} operators from API');

      // 4 — Build a lookup map of local dispensaries keyed by stashpassOperatorId
      final dispensariesProvider = context.read<DispensariesProvider>();
      final byOpId = <String, Dispensary>{
        for (final d in dispensariesProvider.dispensaries)
          if (d.stashpassOperatorId != null) d.stashpassOperatorId!: d,
      };

      // 5 — Upsert profiles for matched dispensaries; auto-create/update local records
      final profilesProvider = context.read<DispensaryProfilesProvider>();
      for (final op in operators) {
        final opId = op['id'] as String?;
        if (opId == null) continue;

        final resolvedVenueType = op['subcategory'] as String? ?? op['category'] as String?;
        print('[sync] ${op['name']} category=${op['category']} subcategory=${op['subcategory']} resolved=$resolvedVenueType');

        Dispensary? dispensary = byOpId[opId];
        if (dispensary == null) {
          // New operator — create local record
          dispensary = Dispensary(
            id: const Uuid().v4(),
            name: op['name'] as String? ?? 'Unknown',
            city: op['city'] as String?,
            state: op['state'] as String?,
            venueType: resolvedVenueType,
            stashpassOperatorId: opId,
            wouldGoBack: 1,
          );
          await dispensariesProvider.add(dispensary);
          print('[sync] created local dispensary for ${op['name']} venueType=$resolvedVenueType');
        } else {
          // Existing record — update API-sourced fields; preserve user ratings/notes
          final updated = Dispensary(
            id: dispensary.id,
            name: op['name'] as String? ?? dispensary.name,
            city: op['city'] as String? ?? dispensary.city,
            state: op['state'] as String? ?? dispensary.state,
            venueType: resolvedVenueType ?? dispensary.venueType,
            apiSource: dispensary.apiSource,
            externalId: dispensary.externalId,
            vibeRating: dispensary.vibeRating,
            priceTier: dispensary.priceTier,
            staffRating: dispensary.staffRating,
            wouldGoBack: dispensary.wouldGoBack,
            createdAt: dispensary.createdAt,
            stashpassOperatorId: dispensary.stashpassOperatorId,
            notes: dispensary.notes,
          );
          await dispensariesProvider.update(updated);
          dispensary = updated;
          print('[sync] updated existing dispensary for ${op['name']} venueType=$resolvedVenueType');
        }

        final rawProfile = op['profile'] as Map<String, dynamic>?;
        if (rawProfile == null) continue;

        await profilesProvider.save(_profileFromApi(dispensary.id, rawProfile));
      }
    } catch (_) {
      // Network or DB error — silently fall through to list reload
    }

    // 6 — Reload dispensary list from DB
    if (mounted) await context.read<DispensariesProvider>().load();
  }

  DispensaryProfile _profileFromApi(String dispensaryId, Map<String, dynamic> p) {
    int _flag(dynamic v) => (v == true || v == 1) ? 1 : 0;

    return DispensaryProfile(
      id: const Uuid().v4(),
      dispensaryId: dispensaryId,
      about: p['about'] as String?,
      hours: p['hours'] != null ? jsonEncode(p['hours']) : null,
      website: p['website'] as String?,
      instagram: p['instagram'] as String?,
      leaflyUrl: p['leafly_url'] as String?,
      dutchieUrl: p['dutchie_url'] as String?,
      otherOrderingUrl: p['other_ordering_url'] as String?,
      orderingPlatform: p['ordering_platform'] as String?,
      paymentMethods: p['payment_methods'] != null ? jsonEncode(p['payment_methods']) : null,
      blackOwned: _flag(p['black_owned']),
      womanOwned: _flag(p['woman_owned']),
      lgbtqFriendly: _flag(p['lgbtq_friendly']),
      veteranOwned: _flag(p['veteran_owned']),
      specials: p['specials'] != null ? jsonEncode(p['specials']) : null,
      dateUpdated: DateTime.now().millisecondsSinceEpoch,
      primaryColor: p['primary_color'] as String?,
      secondaryColor: p['secondary_color'] as String?,
      backgroundColor: p['background_color'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DispensariesProvider>(
      builder: (context, provider, _) {
        print('[discover] local dispensaries count: ${provider.dispensaries.length}');
        print('[discover] operator profiles loaded: ${context.read<DispensaryProfilesProvider>().profileCount}');
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator(color: C.accent));
        }

        final filtered = widget.venueFilter == null
            ? provider.dispensaries
            : provider.dispensaries.where((d) => d.venueType == widget.venueFilter).toList();

        final types = provider.dispensaries
            .map((d) => d.venueType)
            .whereType<String>()
            .toSet()
            .toList();

        return RefreshIndicator(
          color: C.accent,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: widget.venueFilter == null,
                        onTap: () => widget.onVenueFilterChanged(null),
                      ),
                      ...types.map((t) {
                        final sel = widget.venueFilter == t;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _FilterChip(
                            label: _venueLabels[t] ?? t,
                            selected: sel,
                            onTap: () => widget.onVenueFilterChanged(sel ? null : t),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No dispensaries yet', style: TextStyle(color: C.muted))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _DispensaryCard(dispensary: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StrainCard extends StatelessWidget {
  final Strain strain;
  const _StrainCard({required this.strain});

  @override
  Widget build(BuildContext context) {
    final s = strain;
    final typeColor = switch (s.strainType?.toLowerCase()) {
      'sativa' => C.sage,
      'hybrid' => C.amber,
      'indica' => C.danger,
      _ => C.muted,
    };

    return GestureDetector(
      onTap: () => context.push('/discover/strain/${s.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: typeColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_florist, color: typeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 15)),
                  if (s.brand != null && s.brand!.isNotEmpty)
                    Text(s.brand!, style: const TextStyle(color: C.muted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (s.strainType != null)
                  Text(
                    s.strainType![0].toUpperCase() + s.strainType!.substring(1),
                    style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                if (s.category != null)
                  Text(s.category!, style: const TextStyle(color: C.light, fontSize: 12)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: C.light, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DispensaryCard extends StatelessWidget {
  final Dispensary dispensary;
  const _DispensaryCard({required this.dispensary});

  @override
  Widget build(BuildContext context) {
    final d = dispensary;
    final venueLabel = _venueLabels[d.venueType] ?? d.venueType ?? 'Retail';

    return GestureDetector(
      onTap: () => context.push('/discover/dispensary/${d.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: C.accent.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_outlined, color: C.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(venueLabel, style: const TextStyle(color: C.muted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (d.priceTier != null)
                  Text(
                    switch (d.priceTier) {
                      'budget' => '\$',
                      'premium' => '\$\$\$',
                      _ => '\$\$',
                    },
                    style: const TextStyle(color: C.light, fontSize: 12),
                  ),
                if (d.staffRating != null)
                  _MiniStars(label: 'Staff', rating: d.staffRating!),
                if (d.vibeRating != null)
                  _MiniStars(label: 'Vibe', rating: d.vibeRating!),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: C.light, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MiniStars extends StatelessWidget {
  final String label;
  final int rating;

  const _MiniStars({required this.label, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: const TextStyle(color: C.light, fontSize: 10)),
        ...List.generate(5, (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 10,
          color: C.gold,
        )),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.withAlpha(30) : C.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : C.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? c : C.muted,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
