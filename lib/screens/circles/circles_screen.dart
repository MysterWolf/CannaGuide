import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class CirclesScreen extends StatelessWidget {
  const CirclesScreen({super.key});

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
                'Circles',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 22),
              ),
            ),
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined, size: 64, color: C.light),
                    const SizedBox(height: 16),
                    const Text('Circles coming soon', style: TextStyle(color: C.muted, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Share sessions with your crew', style: TextStyle(color: C.light, fontSize: 14)),
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
