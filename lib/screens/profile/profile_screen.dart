import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                'Profile',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 22),
              ),
            ),
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: C.accentLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.accent.withAlpha(60)),
                      ),
                      child: const Icon(Icons.person, size: 40, color: C.accent),
                    ),
                    const SizedBox(height: 16),
                    const Text('Your effect profile', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text('Log more sessions to generate\nyour AI-powered profile', textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 14)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: C.purpleLt,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: C.purple.withAlpha(60)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: C.purple),
                          SizedBox(width: 6),
                          Text('AI Feature', style: TextStyle(color: C.purpleMid, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
