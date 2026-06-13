import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../db/database.dart';
import '../../db/models/strain.dart';
import '../../theme/colors.dart';

class StrainDetailScreen extends StatefulWidget {
  final String strainId;
  const StrainDetailScreen({super.key, required this.strainId});

  @override
  State<StrainDetailScreen> createState() => _StrainDetailScreenState();
}

class _StrainDetailScreenState extends State<StrainDetailScreen> {
  Strain? _strain;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final strain = await AppDatabase.getStrain(widget.strainId);
    final sessions = await AppDatabase.getSessionsForStrainId(widget.strainId);
    if (mounted) {
      setState(() {
        _strain = strain;
        _sessions = sessions;
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

    final s = _strain;
    if (s == null) {
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(backgroundColor: C.bg, leading: const BackButton()),
        body: const Center(child: Text('Strain not found', style: TextStyle(color: C.muted))),
      );
    }

    final typeColor = switch (s.strainType?.toLowerCase()) {
      'sativa' => C.sage,
      'hybrid' => C.amber,
      'indica' => C.danger,
      _ => C.muted,
    };
    final typeBg = switch (s.strainType?.toLowerCase()) {
      'sativa' => C.sageLt,
      'hybrid' => C.amberLt,
      'indica' => C.dangerLt,
      _ => C.surface,
    };

    final avgRating = _sessions.isEmpty
        ? null
        : _sessions
                .where((r) => r['overall_rating'] != null)
                .fold<double>(0, (sum, r) => sum + (r['overall_rating'] as int).toDouble()) /
            _sessions.where((r) => r['overall_rating'] != null).length;

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
                icon: const Icon(Icons.share_outlined),
                onPressed: () => context.push(
                  Uri(
                    path: '/share',
                    queryParameters: {
                      'type': 'strain',
                      'name': s.name,
                      'sub': s.brand ?? '',
                    },
                  ).toString(),
                ),
                tooltip: 'Share to Circle',
              ),
            ],
            title: Text(s.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
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
                      color: typeBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: typeColor.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: typeColor.withAlpha(40),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.local_florist, color: typeColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 20)),
                              if (s.brand != null && s.brand!.isNotEmpty)
                                Text(s.brand!, style: const TextStyle(color: C.muted, fontSize: 14)),
                              const SizedBox(height: 6),
                              if (s.strainType != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: typeColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: typeColor.withAlpha(80)),
                                  ),
                                  child: Text(
                                    s.strainType![0].toUpperCase() + s.strainType!.substring(1),
                                    style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      _StatChip(label: 'Sessions', value: _sessions.length.toString()),
                      const SizedBox(width: 10),
                      if (avgRating != null && !avgRating.isNaN)
                        _StatChip(label: 'Avg rating', value: '${avgRating.toStringAsFixed(1)}/5'),
                      if (s.thcPct != null) ...[
                        const SizedBox(width: 10),
                        _StatChip(label: 'THC', value: '${s.thcPct!.toStringAsFixed(1)}%'),
                      ],
                    ],
                  ),

                  if (s.category != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.category_outlined, size: 16, color: C.muted),
                        const SizedBox(width: 6),
                        Text(s.category!, style: const TextStyle(color: C.muted, fontSize: 14)),
                      ],
                    ),
                  ],

                  if (s.description != null && s.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Description', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(s.description!, style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
                  ],

                  if (s.notes != null && s.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Notes', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(s.notes!, style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
                  ],

                  if (s.terpeneProfile != null && s.terpeneProfile!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Terpene profile', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(s.terpeneProfile!, style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
                  ],

                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.spa_outlined),
                          label: const Text('Log Session'),
                          onPressed: () => context.push('/log-session?strainId=${s.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: C.accent,
                            side: const BorderSide(color: C.accent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.group_outlined),
                          label: const Text('Share'),
                          onPressed: () => context.push(
                            Uri(
                              path: '/share',
                              queryParameters: {
                                'type': 'strain',
                                'name': s.name,
                                'sub': s.brand ?? '',
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
                    ],
                  ),

                  if (_sessions.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text('Sessions with this strain', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    ..._sessions.map((r) => _SessionMiniCard(row: r)),
                  ],

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

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.border),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
            Text(label, style: const TextStyle(color: C.muted, fontSize: 12)),
          ],
        ),
      );
}

class _SessionMiniCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _SessionMiniCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final rating = row['overall_rating'] as int?;
    final sessionAt = row['session_at'] as String? ?? '';
    DateTime? date;
    try { date = DateTime.parse(sessionAt); } catch (_) {}
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : sessionAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(dateStr, style: const TextStyle(color: C.muted, fontSize: 13)),
          ),
          if (rating != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) => Icon(
                i < rating ? Icons.star : Icons.star_border,
                size: 14,
                color: C.gold,
              )),
            ),
        ],
      ),
    );
  }
}
