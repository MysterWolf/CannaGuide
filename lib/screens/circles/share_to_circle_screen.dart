import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/circles_provider.dart';
import '../../theme/colors.dart';

class ShareToCircleScreen extends StatefulWidget {
  final String circleId;
  final String? preloadType;
  final String? preloadName;
  final String? preloadSub;

  const ShareToCircleScreen({
    super.key,
    required this.circleId,
    this.preloadType,
    this.preloadName,
    this.preloadSub,
  });

  @override
  State<ShareToCircleScreen> createState() => _ShareToCircleScreenState();
}

class _ShareToCircleScreenState extends State<ShareToCircleScreen> {
  late String _type;
  final _nameCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _type = widget.preloadType ?? 'strain';
    if (widget.preloadName != null) _nameCtrl.text = widget.preloadName!;
    if (widget.preloadSub != null) _subCtrl.text = widget.preloadSub!;
  }

  Future<void> _share() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _sharing = true);
    await context.read<CirclesProvider>().addShare(
          circleId: widget.circleId,
          type: _type,
          payload: {'name': name, 'sub': _subCtrl.text.trim()},
          note: _noteCtrl.text.trim(),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('Share to Circle', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _sharing ? null : _share,
            child: Text('Post', style: TextStyle(color: _sharing ? C.muted : C.circles, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(_type == 'strain' ? 'Strain name' : _type == 'dispensary' ? 'Dispensary name' : 'Product name',
                style: const TextStyle(color: C.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(controller: _nameCtrl, decoration: _dec('Name')),
            const SizedBox(height: 16),
            Text(_type == 'strain' ? 'Brand (optional)' : _type == 'dispensary' ? 'City (optional)' : 'Brand (optional)',
                style: const TextStyle(color: C.text, fontWeight: FontWeight.w600)),
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
