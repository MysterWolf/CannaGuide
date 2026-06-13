import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/sessions_provider.dart';
import '../../theme/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: C.bg,
              floating: true,
              title: const Text(
                'CannaGuide',
                style: TextStyle(
                  color: C.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    _QuickAction(
                      icon: Icons.spa_outlined,
                      label: 'Log Session',
                      onTap: () => context.push('/log-session'),
                    ),
                    const SizedBox(width: 8),
                    _QuickAction(
                      icon: Icons.local_florist_outlined,
                      label: 'Add Strain',
                      onTap: () => context.push('/add-strain'),
                    ),
                    const SizedBox(width: 8),
                    _QuickAction(
                      icon: Icons.storefront_outlined,
                      label: 'Add Dispensary',
                      onTap: () => context.push('/add-dispensary'),
                    ),
                  ],
                ),
              ),
            ),
            Consumer<SessionsProvider>(
              builder: (context, provider, _) {
                if (provider.loading) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: C.accent)),
                  );
                }

                if (provider.diary.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.spa_outlined, size: 64, color: C.light),
                          const SizedBox(height: 16),
                          Text('No sessions yet', style: TextStyle(color: C.muted, fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Tap + to log your first session', style: TextStyle(color: C.light, fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final row = provider.diary[i];
                        return _SessionCard(row: row);
                      },
                      childCount: provider.diary.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: C.accentLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.accent.withAlpha(60)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: C.accent, size: 22),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(color: C.accent, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _SessionCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final strainName = row['strain_name'] as String? ?? 'Unknown strain';
    final brand = row['strain_brand'] as String?;
    final dispensaryName = row['dispensary_name'] as String?;
    final sessionAt = row['session_at'] as String? ?? '';
    final rating = row['overall_rating'] as int?;
    final timeOfDay = row['time_of_day'] as String?;
    final strainType = row['strain_type'] as String?;

    DateTime? date;
    try {
      date = DateTime.parse(sessionAt);
    } catch (_) {}

    final dateStr = date != null ? DateFormat('MMM d, yyyy').format(date.toLocal()) : sessionAt;

    final typeColor = switch (strainType?.toLowerCase()) {
      'sativa' => C.sage,
      'hybrid' => C.amber,
      'indica' => C.danger,
      _ => C.muted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strainName,
                      style: const TextStyle(
                        color: C.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    if (brand != null && brand.isNotEmpty)
                      Text(brand, style: const TextStyle(color: C.muted, fontSize: 13)),
                  ],
                ),
              ),
              if (rating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      size: 14,
                      color: C.gold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (strainType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: typeColor.withAlpha(80)),
                  ),
                  child: Text(
                    strainType[0].toUpperCase() + strainType.substring(1),
                    style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              if (strainType != null) const SizedBox(width: 6),
              if (timeOfDay != null)
                Text(timeOfDay, style: const TextStyle(color: C.muted, fontSize: 12)),
              const Spacer(),
              Text(dateStr, style: const TextStyle(color: C.light, fontSize: 12)),
            ],
          ),
          if (dispensaryName != null && dispensaryName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 12, color: C.light),
                const SizedBox(width: 4),
                Text(dispensaryName, style: const TextStyle(color: C.light, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
