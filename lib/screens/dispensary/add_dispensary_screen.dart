import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../db/models/dispensary.dart';
import '../../providers/dispensaries_provider.dart';
import '../../theme/colors.dart';

const _uuid = Uuid();

const _categories = [
  ('dispensary', 'Dispensary'),
  ('wellness_retail', 'Wellness Retail'),
  ('smoke_shop', 'Smoke Shop'),
  ('liquor_store', 'Liquor Store'),
  ('general_retail', 'General Retail'),
];

const _priceTiers = [
  ('budget', 'Budget \$'),
  ('mid', 'Mid \$\$'),
  ('premium', 'Premium \$\$\$'),
];

class AddDispensaryScreen extends StatefulWidget {
  const AddDispensaryScreen({super.key});

  @override
  State<AddDispensaryScreen> createState() => _AddDispensaryScreenState();
}

class _AddDispensaryScreenState extends State<AddDispensaryScreen> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _venueType = 'dispensary';
  String _priceTier = 'mid';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final d = Dispensary(
      id: _uuid.v4(),
      name: name,
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      venueType: _venueType,
      priceTier: _priceTier,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      wouldGoBack: 1,
    );
    await context.read<DispensariesProvider>().add(d);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('Add Dispensary', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text('Save', style: TextStyle(color: _saving ? C.muted : C.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Name *'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: _dec('e.g. Green Leaf Dispensary'),
            ),

            const SizedBox(height: 20),
            _label('Location'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(controller: _cityCtrl, decoration: _dec('City')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(controller: _stateCtrl, decoration: _dec('State')),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _label('Category'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map(((String key, String label) pair) {
                final sel = pair.$1 == _venueType;
                return ChoiceChip(
                  label: Text(pair.$2),
                  selected: sel,
                  onSelected: (_) => setState(() => _venueType = pair.$1),
                  selectedColor: C.accentLight,
                  side: BorderSide(color: sel ? C.accent : C.border),
                  labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            _label('Price tier'),
            const SizedBox(height: 8),
            Row(
              children: _priceTiers.map(((String key, String label) pair) {
                final sel = pair.$1 == _priceTier;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(pair.$2),
                    selected: sel,
                    onSelected: (_) => setState(() => _priceTier = pair.$1),
                    selectedColor: C.accentLight,
                    side: BorderSide(color: sel ? C.accent : C.border),
                    labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            _label('Notes (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _dec('Anything worth remembering…'),
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: C.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Dispensary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14));

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: C.light),
        filled: true,
        fillColor: C.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.accent)),
      );
}
