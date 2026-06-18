import 'package:flutter/material.dart';
import '../theme/colors.dart';

// Provenance badge — visible whenever an item is linked to the StashPass network.
// Gated on stashpassId != null only. Does NOT check hasContent — persists in both
// pending (state 2) and enriched (state 3). Hidden only when not matched (state 1).
// Icon and color are placeholder — pending visual refinement on device.
class StashPassBadge extends StatelessWidget {
  const StashPassBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: C.accentLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.accent.withAlpha(80)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, size: 11, color: C.accent),
            SizedBox(width: 4),
            Text(
              'StashPass',
              style: TextStyle(
                color: C.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}
