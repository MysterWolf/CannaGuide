import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/strains_provider.dart';
import '../../theme/colors.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StrainsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              backgroundColor: C.bg,
              floating: true,
              title: Text(
                'Discover',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 22),
              ),
            ),
            Consumer<StrainsProvider>(
              builder: (context, provider, _) {
                if (provider.loading) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator(color: C.accent)),
                  );
                }

                if (provider.strains.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No strains yet', style: TextStyle(color: C.muted))),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final s = provider.strains[i];
                        final typeColor = switch (s.strainType?.toLowerCase()) {
                          'sativa' => C.sage,
                          'hybrid' => C.amber,
                          'indica' => C.danger,
                          _ => C.muted,
                        };
                        return Container(
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
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: typeColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.local_florist, color: typeColor, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600)),
                                    if (s.brand != null && s.brand!.isNotEmpty)
                                      Text(s.brand!, style: const TextStyle(color: C.muted, fontSize: 13)),
                                  ],
                                ),
                              ),
                              if (s.strainType != null)
                                Text(
                                  s.strainType!,
                                  style: TextStyle(color: typeColor, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                            ],
                          ),
                        );
                      },
                      childCount: provider.strains.length,
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
