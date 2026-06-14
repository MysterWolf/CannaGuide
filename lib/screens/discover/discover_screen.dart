import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../db/models/dispensary.dart';
import '../../db/models/strain.dart';
import '../../providers/dispensaries_provider.dart';
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

class _StrainsTab extends StatelessWidget {
  final String? typeFilter;
  final ValueChanged<String?> onTypeFilterChanged;

  const _StrainsTab({required this.typeFilter, required this.onTypeFilterChanged});

  @override
  Widget build(BuildContext context) {
    return Consumer<StrainsProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator(color: C.accent));
        }

        final filtered = typeFilter == null
            ? provider.strains
            : provider.strains.where((s) => s.strainType?.toLowerCase() == typeFilter).toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _FilterChip(label: 'All', selected: typeFilter == null, onTap: () => onTypeFilterChanged(null)),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Sativa', selected: typeFilter == 'sativa', color: C.sage, onTap: () => onTypeFilterChanged(typeFilter == 'sativa' ? null : 'sativa')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Hybrid', selected: typeFilter == 'hybrid', color: C.amber, onTap: () => onTypeFilterChanged(typeFilter == 'hybrid' ? null : 'hybrid')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Indica', selected: typeFilter == 'indica', color: C.danger, onTap: () => onTypeFilterChanged(typeFilter == 'indica' ? null : 'indica')),
                  ],
                ),
              ),
            ),
            if (filtered.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No strains yet', style: TextStyle(color: C.muted))),
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
        );
      },
    );
  }
}

class _DispensariesTab extends StatelessWidget {
  final String? venueFilter;
  final ValueChanged<String?> onVenueFilterChanged;

  const _DispensariesTab({required this.venueFilter, required this.onVenueFilterChanged});

  @override
  Widget build(BuildContext context) {
    return Consumer<DispensariesProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator(color: C.accent));
        }

        final filtered = venueFilter == null
            ? provider.dispensaries
            : provider.dispensaries.where((d) => d.venueType == venueFilter).toList();

        // Distinct venue types for filter chips
        final types = provider.dispensaries
            .map((d) => d.venueType)
            .whereType<String>()
            .toSet()
            .toList();

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: venueFilter == null,
                      onTap: () => onVenueFilterChanged(null),
                    ),
                    ...types.map((t) {
                      final sel = venueFilter == t;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: _venueLabels[t] ?? t,
                          selected: sel,
                          onTap: () => onVenueFilterChanged(sel ? null : t),
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
    final location = [d.city, d.state].where((v) => v != null && v.isNotEmpty).join(', ');

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
                  if (location.isNotEmpty)
                    Text(location, style: const TextStyle(color: C.muted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(venueLabel, style: const TextStyle(color: C.accent, fontSize: 12, fontWeight: FontWeight.w500)),
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
