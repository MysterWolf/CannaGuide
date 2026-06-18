import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../db/database.dart';
import '../../db/models/strain.dart';
import '../../db/models/strain_profile.dart';
import '../../providers/strain_profiles_provider.dart';
import '../../providers/strains_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/stashpass_badge.dart';

class StrainDetailScreen extends StatefulWidget {
  final String strainId;
  const StrainDetailScreen({super.key, required this.strainId});

  @override
  State<StrainDetailScreen> createState() => _StrainDetailScreenState();
}

class _StrainDetailScreenState extends State<StrainDetailScreen> {
  Strain? _strain;
  StrainProfile? _profile;
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  // Inline notes edit state
  bool _editingNotes = false;
  final _notesCtrl = TextEditingController();
  bool _savingNotes = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final strain = await AppDatabase.getStrain(widget.strainId);
    final sessions = await AppDatabase.getSessionsForStrainId(widget.strainId);
    StrainProfile? profile;
    if (strain != null && mounted) {
      profile = await context.read<StrainProfilesProvider>().load(strain.id);
    }
    if (mounted) {
      setState(() {
        _strain = strain;
        _profile = profile;
        _notesCtrl.text = strain?.notes ?? '';
        _sessions = sessions;
        _loading = false;
        _editingNotes = false;
      });
    }
  }

  Future<void> _saveNotes() async {
    final s = _strain;
    if (s == null) return;
    setState(() => _savingNotes = true);
    final updated = s.copyWith(
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      clearNotes: _notesCtrl.text.trim().isEmpty,
    );
    await context.read<StrainsProvider>().update(updated);
    await _load();
    if (mounted) setState(() => _savingNotes = false);
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
                .fold<double>(0, (sum, r) => sum + (r['overall_rating'] as num).toDouble()) /
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
                icon: const Icon(Icons.edit_outlined),
                color: C.muted,
                tooltip: 'Edit strain',
                onPressed: () async {
                  await context.push('/discover/strain/${s.id}/edit');
                  _load();
                },
              ),
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
                              if (s.stashpassStrainId != null) ...[
                                const SizedBox(height: 4),
                                const StashPassBadge(),
                              ],
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

                  if (s.terpeneProfile != null && s.terpeneProfile!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Terpene profile', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(s.terpeneProfile!, style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
                  ],

                  // ── Notes section (always visible, inline editable) ──────────
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _editingNotes ? C.accent : C.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Notes', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                            const Spacer(),
                            if (!_editingNotes)
                              GestureDetector(
                                onTap: () => setState(() => _editingNotes = true),
                                child: const Icon(Icons.edit_outlined, size: 18, color: C.muted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_editingNotes) ...[
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Terpene notes, appearance, anything memorable…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _savingNotes ? null : () {
                                  _notesCtrl.text = s.notes ?? '';
                                  setState(() => _editingNotes = false);
                                },
                                child: const Text('Cancel', style: TextStyle(color: C.muted)),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: C.accent),
                                onPressed: _savingNotes ? null : _saveNotes,
                                child: _savingNotes
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Save'),
                              ),
                            ],
                          ),
                        ] else ...[
                          if (s.notes != null && s.notes!.isNotEmpty)
                            Text(s.notes!, style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5))
                          else
                            const Text('Tap pencil to add notes…', style: TextStyle(color: C.light, fontSize: 14)),
                        ],
                      ],
                    ),
                  ),

                  // ── StashPass origin status (states 1 and 2) ─────────────────
                  if (s.stashpassStrainId == null || _profile == null || !_profile!.hasContent) ...[
                    const SizedBox(height: 20),
                    _StashPassStatusRow(isMatched: s.stashpassStrainId != null),
                  ],

                  // ── Curated intelligence (from StashPass, state 3) ───────────
                  if (_profile != null && _profile!.hasContent) ...[
                    const SizedBox(height: 24),
                    _StrainProfileSection(profile: _profile!),
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

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Strain'),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete this strain?'),
                            content: const Text(
                              'Sessions logged with it will keep their data but lose the strain link.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: C.danger)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          await context.read<StrainsProvider>().delete(s.id);
                          if (mounted) context.pop();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.danger,
                        side: const BorderSide(color: C.danger),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
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
    final rating = (row['overall_rating'] as num?)?.toInt();
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

// ─────────────────────────────────────────────────────────────────────────────
// Curated intelligence section — populated from StashPass strain profile
// ─────────────────────────────────────────────────────────────────────────────

class _StrainProfileSection extends StatelessWidget {
  final StrainProfile profile;
  const _StrainProfileSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final terpenes = profile.terpenesList;
    final effects = profile.primaryEffectsList;
    final flavors = profile.flavorList;
    final useCases = profile.useCasesList;
    final hasCannabinoids = profile.thcMin != null || profile.thcMax != null ||
        profile.cbdMin != null || profile.cbdMax != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: C.accent),
              const SizedBox(width: 8),
              const Text(
                'Curated Intelligence',
                style: TextStyle(
                  color: C.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (profile.beginnerFriendly == 1) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: C.sageLt,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: C.sage.withAlpha(80)),
                  ),
                  child: const Text(
                    'Beginner Friendly',
                    style: TextStyle(color: C.sage, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),

          // Lineage + best method
          if (profile.lineage != null || profile.bestMethod != null) ...[
            const SizedBox(height: 12),
            if (profile.lineage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lineage  ', style: TextStyle(color: C.muted, fontSize: 12)),
                    Expanded(
                      child: Text(profile.lineage!,
                          style: const TextStyle(color: C.text, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            if (profile.bestMethod != null)
              Row(
                children: [
                  const Text('Best method  ', style: TextStyle(color: C.muted, fontSize: 12)),
                  Text(profile.bestMethod!,
                      style: const TextStyle(color: C.text, fontSize: 12)),
                ],
              ),
          ],

          // Cannabinoid range
          if (hasCannabinoids) ...[
            const SizedBox(height: 12),
            const Divider(color: C.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                if (profile.thcMin != null || profile.thcMax != null)
                  _CannabinoidRange(
                    label: 'THC',
                    min: profile.thcMin,
                    max: profile.thcMax,
                    color: C.amber,
                  ),
                if ((profile.thcMin != null || profile.thcMax != null) &&
                    (profile.cbdMin != null || profile.cbdMax != null))
                  const SizedBox(width: 16),
                if (profile.cbdMin != null || profile.cbdMax != null)
                  _CannabinoidRange(
                    label: 'CBD',
                    min: profile.cbdMin,
                    max: profile.cbdMax,
                    color: C.sage,
                  ),
              ],
            ),
          ],

          // About
          if (profile.about != null && profile.about!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: C.border, height: 1),
            const SizedBox(height: 12),
            Text(profile.about!,
                style: const TextStyle(color: C.muted, fontSize: 13, height: 1.5)),
          ],

          // Primary effects
          if (effects.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: C.border, height: 1),
            const SizedBox(height: 12),
            const Text('Effects',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: effects
                  .map((e) => _ProfileChip(label: e, color: C.sage, bg: C.sageLt))
                  .toList(),
            ),
          ],

          // Flavors
          if (flavors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: C.border, height: 1),
            const SizedBox(height: 12),
            const Text('Flavor Profile',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: flavors
                  .map((f) => _ProfileChip(label: f, color: C.amber, bg: C.amberLt))
                  .toList(),
            ),
          ],

          // Terpenes
          if (terpenes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: C.border, height: 1),
            const SizedBox(height: 12),
            const Text('Terpenes',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            ...terpenes.map((t) {
              final name = t['name'] as String? ?? '';
              final effect = t['effect'] as String? ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: C.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$name ',
                              style: const TextStyle(
                                  color: C.text, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (effect.isNotEmpty)
                              TextSpan(
                                text: '— $effect',
                                style: const TextStyle(color: C.muted, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Use cases
          if (useCases.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: C.border, height: 1),
            const SizedBox(height: 12),
            const Text('Use Cases',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: useCases
                  .map((u) => _ProfileChip(label: u, color: C.blue, bg: C.blueLt))
                  .toList(),
            ),
          ],

          // Cautions
          if (profile.cautions != null && profile.cautions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: C.border, height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: C.amber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(profile.cautions!,
                      style: const TextStyle(color: C.muted, fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CannabinoidRange extends StatelessWidget {
  final String label;
  final double? min;
  final double? max;
  final Color color;

  const _CannabinoidRange(
      {required this.label, this.min, this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final String rangeText;
    if (min != null && max != null) {
      rangeText = '${min!.toStringAsFixed(1)}–${max!.toStringAsFixed(1)}%';
    } else if (min != null) {
      rangeText = '${min!.toStringAsFixed(1)}%+';
    } else {
      rangeText = '≤${max!.toStringAsFixed(1)}%';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(rangeText,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(label,
              style: const TextStyle(color: C.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StashPass origin / enrichment status row
// State 1 (isMatched=false): muted — strain not in StashPass network
// State 2 (isMatched=true):  purple — matched but curated profile not ready yet
// State 3: this widget is not shown — the Curated Intelligence card renders instead
// ─────────────────────────────────────────────────────────────────────────────

class _StashPassStatusRow extends StatelessWidget {
  final bool isMatched;
  const _StashPassStatusRow({required this.isMatched});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isMatched ? Icons.auto_awesome_outlined : Icons.radio_button_unchecked,
            size: 14,
            color: isMatched ? C.purple : C.muted,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              isMatched
                  ? 'On the radar — we\'re building out the full profile'
                  : 'Not yet in the StashPass network',
              style: TextStyle(
                color: isMatched ? C.purple : C.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
}

class _ProfileChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _ProfileChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      );
}
