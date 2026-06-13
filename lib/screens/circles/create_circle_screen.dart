import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/circles_provider.dart';
import '../../theme/colors.dart';

const _emojiOptions = ['🌿', '🍃', '🔥', '✨', '🌙', '💫', '🌈', '🦋', '🎯', '🪴', '🌸', '⚡'];

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final _nameCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  String _emoji = '🌿';
  final List<String> _members = [];
  bool _creating = false;

  void _addMember() {
    final name = _memberCtrl.text.trim();
    if (name.isEmpty || _members.contains(name)) return;
    setState(() => _members.add(name));
    _memberCtrl.clear();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    final provider = context.read<CirclesProvider>();
    final id = await provider.createCircle(name, _emoji, List.from(_members));
    if (mounted) {
      context.pop();
      context.push('/circles/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('New Circle', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: Text('Create', style: TextStyle(color: _creating ? C.muted : C.circles, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Circle name', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: _inputDecoration('e.g. Weekend Crew'),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            const Text('Pick an emoji', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _emojiOptions.map((e) {
                final sel = e == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: sel ? C.circlesLt : C.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? C.circles : C.border, width: sel ? 2 : 1),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            const Text('Add members', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
            const Text('Add by display name (they can also join via invite link)', style: TextStyle(color: C.muted, fontSize: 13)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberCtrl,
                    decoration: _inputDecoration('Display name'),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: C.circles),
                  icon: const Icon(Icons.add, color: C.white),
                  onPressed: _addMember,
                ),
              ],
            ),
            if (_members.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _members.map((m) => Chip(
                  label: Text(m),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _members.remove(m)),
                  backgroundColor: C.circlesLt,
                  side: const BorderSide(color: C.circles),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: C.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.circles)),
      );
}

