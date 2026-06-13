import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/circles_provider.dart';
import '../../theme/colors.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CirclesProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CirclesProvider>(
      builder: (context, provider, _) {
        if (!provider.hasProfile) {
          return _ProfileSetup(provider: provider);
        }

        return Scaffold(
          backgroundColor: C.bg,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: C.bg,
                  floating: true,
                  title: const Text('Circles', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 22)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add, color: C.circles),
                      onPressed: () => context.push('/circles/create'),
                    ),
                  ],
                ),
                if (provider.circles.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined, size: 64, color: C.light),
                          const SizedBox(height: 16),
                          const Text('No circles yet', style: TextStyle(color: C.muted, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('Create one to share with your crew', style: TextStyle(color: C.light, fontSize: 14)),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: C.circles),
                            icon: const Icon(Icons.add),
                            label: const Text('Create Circle'),
                            onPressed: () => context.push('/circles/create'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final circle = provider.circles[i];
                          return _CircleCard(circle: circle, onTap: () => context.push('/circles/${circle['id']}'));
                        },
                        childCount: provider.circles.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircleCard extends StatelessWidget {
  final Map<String, dynamic> circle;
  final VoidCallback onTap;
  const _CircleCard({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = circle['name'] as String? ?? '';
    final emoji = circle['emoji'] as String? ?? '🌿';
    final createdAt = circle['created_at'] as int? ?? 0;
    final dateStr = DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(createdAt));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: C.circlesLt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 16)),
                  Text('Created $dateStr', style: const TextStyle(color: C.muted, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: C.light),
          ],
        ),
      ),
    );
  }
}

class _ProfileSetup extends StatefulWidget {
  final CirclesProvider provider;
  const _ProfileSetup({required this.provider});

  @override
  State<_ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<_ProfileSetup> {
  final _ctrl = TextEditingController();
  String _selectedAvatar = '🌿';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const Text('Set up your\nCircles profile', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 28)),
              const SizedBox(height: 8),
              const Text('Your display name is visible to circle members.', style: TextStyle(color: C.muted, fontSize: 15)),
              const SizedBox(height: 32),
              const Text('Display name', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: 'Your name',
                  filled: true,
                  fillColor: C.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Choose an avatar', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: widget.provider.avatarOptions.map((a) {
                  final selected = a == _selectedAvatar;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatar = a),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected ? C.circlesLt : C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? C.circles : C.border, width: selected ? 2 : 1),
                      ),
                      child: Center(child: Text(a, style: const TextStyle(fontSize: 26))),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.circles, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () {
                    final name = _ctrl.text.trim();
                    if (name.isEmpty) return;
                    widget.provider.saveProfile(name, _selectedAvatar);
                  },
                  child: const Text('Get Started', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
