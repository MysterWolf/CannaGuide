import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/database.dart';
import '../../db/models/dispensary.dart';
import '../../theme/colors.dart';

const _venueLabels = {
  'dispensary': 'Dispensary',
  'wellness_retail': 'Wellness Retail',
  'smoke_shop': 'Smoke Shop',
  'liquor_store': 'Liquor Store',
  'general_retail': 'General Retail',
};

const _tierLabels = {
  'budget': 'Budget \$',
  'mid': 'Mid \$\$',
  'premium': 'Premium \$\$\$',
};

class DispensaryDetailScreen extends StatefulWidget {
  final String dispensaryId;
  const DispensaryDetailScreen({super.key, required this.dispensaryId});

  @override
  State<DispensaryDetailScreen> createState() => _DispensaryDetailScreenState();
}

class _DispensaryDetailScreenState extends State<DispensaryDetailScreen> {
  Dispensary? _dispensary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppDatabase.getDispensary(widget.dispensaryId);
    if (mounted) {
      setState(() {
        _dispensary = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator(color: C.accent)),
      );
    }

    final d = _dispensary;
    if (d == null) {
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(backgroundColor: C.bg, leading: const BackButton()),
        body: const Center(child: Text('Dispensary not found', style: TextStyle(color: C.muted))),
      );
    }

    final venueLabel = _venueLabels[d.venueType] ?? d.venueType ?? 'Retail';
    final tierLabel = _tierLabels[d.priceTier] ?? d.priceTier;
    final location = [d.city, d.state].where((v) => v != null && v.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: C.bg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context
                    .push('/discover/dispensary/${d.id}/edit')
                    .then((_) => _load()),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => context.push(
                  Uri(
                    path: '/share',
                    queryParameters: {
                      'type': 'dispensary',
                      'name': d.name,
                      'sub': location,
                    },
                  ).toString(),
                ),
                tooltip: 'Share to Circle',
              ),
            ],
            title: Text(d.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.accentLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.accent.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: C.accent.withAlpha(40),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront, color: C.accent, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 20)),
                              if (location.isNotEmpty)
                                Text(location, style: const TextStyle(color: C.muted, fontSize: 14)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _TypeChip(venueLabel),
                                  if (tierLabel != null) ...[
                                    const SizedBox(width: 6),
                                    _TypeChip(tierLabel),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Ratings
                  if (d.staffRating != null || d.vibeRating != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: Column(
                        children: [
                          if (d.staffRating != null)
                            _RatingRow(label: 'Staff Knowledge', rating: d.staffRating!),
                          if (d.staffRating != null && d.vibeRating != null)
                            const SizedBox(height: 10),
                          if (d.vibeRating != null)
                            _RatingRow(label: 'Vibe', rating: d.vibeRating!),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Details
                  if (d.notes != null && d.notes!.isNotEmpty) ...[
                    const Text('Notes', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: Text(d.notes!, style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.group_outlined),
                      label: const Text('Share to Circle'),
                      onPressed: () => context.push(
                        Uri(
                          path: '/share',
                          queryParameters: {
                            'type': 'dispensary',
                            'name': d.name,
                            'sub': location,
                          },
                        ).toString(),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.circles,
                        side: const BorderSide(color: C.circles),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int rating;

  const _RatingRow({required this.label, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: C.muted, fontSize: 13)),
        ),
        ...List.generate(5, (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          size: 18,
          color: C.gold,
        )),
        const SizedBox(width: 6),
        Text('$rating / 5', style: const TextStyle(color: C.muted, fontSize: 12)),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: C.accent.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.accent.withAlpha(60)),
        ),
        child: Text(label, style: const TextStyle(color: C.accent, fontSize: 12, fontWeight: FontWeight.w500)),
      );
}
