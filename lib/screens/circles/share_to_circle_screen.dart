import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/circles_provider.dart';
import '../../theme/colors.dart';

class ShareToCircleScreen extends StatefulWidget {
  /// If null, user selects a circle from their list.
  final String? circleId;
  final String? preloadType;
  final String? preloadName;
  final String? preloadSub;

  const ShareToCircleScreen({
    super.key,
    this.circleId,
    this.preloadType,
    this.preloadName,
    this.preloadSub,
  });

  @override
  State<ShareToCircleScreen> createState() => _ShareToCircleScreenState();
}

class _ShareToCircleScreenState extends State<ShareToCircleScreen> {
  late String _type;
  String? _selectedCircleId;
  final _nameCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _type = widget.preloadType ?? 'strain';
    _selectedCircleId = widget.circleId;
    if (widget.preloadName != null) _nameCtrl.text = widget.preloadName!;
    if (widget.preloadSub != null) _subCtrl.text = widget.preloadSub!;
    if (widget.circleId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<CirclesProvider>().reload();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final name = _nameCtrl.text.trim();
    final targetId = _selectedCircleId;
    if (name.isEmpty || targetId == null) return;
    setState(() => _sharing = true);
    await context.read<CirclesProvider>().addShare(
          circleId: targetId,
          type: _type,
          payload: {'name': name, 'sub': _subCtrl.text.trim()},
          note: _noteCtrl.text.trim(),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool canPost = _nameCtrl.text.trim().isNotEmpty && _selectedCircleId != null;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('Share to Circle', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: (_sharing || !canPost) ? null : _share,
            child: Text('Post', style: TextStyle(color: (_sharing || !canPost) ? C.muted : C.circles, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circle selector — only when circleId is not pre-set
            if (widget.circleId == null) ...[
              const Text('Circle', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Consumer<CirclesProvider>(
                builder: (context, circles, _) {
                  if (!circles.hasProfile) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: const Text(
                        'Set up your profile in the Circles tab first.',
                        style: TextStyle(color: C.muted),
                      ),
                    );
                  }
                  if (circles.circles.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: C.border),
                      ),
                      child: const Text(
                        'You\'re not in any circles yet. Create or join one first.',
                        style: TextStyle(color: C.muted),
                      ),
                    );
                  }
                  return Column(
                    children: circles.circles.map((c) {
                      final id = c['id'] as String;
                      final sel = id == _selectedCircleId;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCircleId = id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: sel ? C.circlesLt : C.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sel ? C.circles : C.border),
                          ),
                          child: Row(
                            children: [
                              Text(c['emoji'] as String? ?? '🌿', style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Text(c['name'] as String? ?? '', style: TextStyle(color: sel ? C.circles : C.text, fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                              const Spacer(),
                              if (sel) const Icon(Icons.check_circle, color: C.circles, size: 20),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            const Text('Type', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: ['strain', 'dispensary', 'product'].map((t) {
                final sel = t == _type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t[0].toUpperCase() + t.substring(1)),
                    selected: sel,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: C.circlesLt,
                    side: BorderSide(color: sel ? C.circles : C.border),
                    labelStyle: TextStyle(color: sel ? C.circles : C.muted),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              _type == 'strain' ? 'Strain name' : _type == 'dispensary' ? 'Dispensary name' : 'Product name',
              style: const TextStyle(color: C.text, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: _dec('Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(
              _type == 'strain' ? 'Brand (optional)' : _type == 'dispensary' ? 'City (optional)' : 'Brand (optional)',
              style: const TextStyle(color: C.text, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(controller: _subCtrl, decoration: _dec('Optional')),
            const SizedBox(height: 20),
            const Text('Your note', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
            const Text('Up to 280 characters', style: TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 4,
              maxLength: 280,
              decoration: _dec('What do you think?'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: C.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.circles)),
      );
}
