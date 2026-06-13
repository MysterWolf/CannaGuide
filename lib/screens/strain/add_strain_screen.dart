import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../db/models/dispensary.dart';
import '../../db/models/strain.dart';
import '../../providers/dispensaries_provider.dart';
import '../../providers/strains_provider.dart';
import '../../theme/colors.dart';

const _uuid = Uuid();

const _strainTypes = ['sativa', 'indica', 'hybrid'];
const _categories = ['Flower', 'Vape', 'Pre-Roll', 'Concentrate', 'Edible', 'Tincture', 'Topical', 'Other'];

class AddStrainScreen extends StatefulWidget {
  const AddStrainScreen({super.key});

  @override
  State<AddStrainScreen> createState() => _AddStrainScreenState();
}

class _AddStrainScreenState extends State<AddStrainScreen> {
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _strainType = 'hybrid';
  String? _category;
  Dispensary? _dispensary;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DispensariesProvider>().load();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final s = Strain(
      id: _uuid.v4(),
      name: name,
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      strainType: _strainType,
      source: 'manual',
      category: _category,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      dispensaryId: _dispensary?.id,
    );
    await context.read<StrainsProvider>().add(s);
    if (mounted) context.pop();
  }

  void _pickDispensary() async {
    final dispensaries = context.read<DispensariesProvider>().dispensaries;
    if (dispensaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No dispensaries yet. Add one first.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Dispensary>(
      context: context,
      builder: (ctx) => _PickerSheet<Dispensary>(
        title: 'Source dispensary',
        items: dispensaries,
        labelOf: (d) => d.name,
        subtitleOf: (d) => d.city,
        selected: _dispensary,
      ),
    );
    if (picked != null) setState(() => _dispensary = picked);
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (_strainType) {
      'sativa' => C.sage,
      'indica' => C.danger,
      _ => C.amber,
    };

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('Add Strain', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
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
            _label('Strain name *'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: _dec('e.g. Blue Dream'),
            ),

            const SizedBox(height: 20),
            _label('Brand / producer (optional)'),
            const SizedBox(height: 6),
            TextField(controller: _brandCtrl, decoration: _dec('e.g. Cookies')),

            const SizedBox(height: 20),
            _label('Type'),
            const SizedBox(height: 8),
            Row(
              children: _strainTypes.map((t) {
                final sel = t == _strainType;
                final color = switch (t) {
                  'sativa' => C.sage,
                  'indica' => C.danger,
                  _ => C.amber,
                };
                final bgColor = switch (t) {
                  'sativa' => C.sageLt,
                  'indica' => C.dangerLt,
                  _ => C.amberLt,
                };
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t[0].toUpperCase() + t.substring(1)),
                    selected: sel,
                    onSelected: (_) => setState(() => _strainType = t),
                    selectedColor: bgColor,
                    side: BorderSide(color: sel ? color : C.border),
                    labelStyle: TextStyle(color: sel ? color : C.muted, fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
                  ),
                );
              }).toList(),
            ),
            if (_strainType.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: typeColor),
                  const SizedBox(width: 6),
                  Text(
                    switch (_strainType) {
                      'sativa' => 'Typically energizing and uplifting',
                      'indica' => 'Typically relaxing and sedating',
                      _ => 'Balanced effects from both types',
                    },
                    style: TextStyle(color: typeColor, fontSize: 12),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            _label('Category (optional)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final sel = c == _category;
                return ChoiceChip(
                  label: Text(c),
                  selected: sel,
                  onSelected: (_) => setState(() => _category = sel ? null : c),
                  selectedColor: C.accentLight,
                  side: BorderSide(color: sel ? C.accent : C.border),
                  labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            _label('Source dispensary (optional)'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDispensary,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storefront_outlined, size: 18, color: _dispensary != null ? C.accent : C.light),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dispensary?.name ?? 'Select dispensary',
                        style: TextStyle(color: _dispensary != null ? C.text : C.light),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: C.light, size: 18),
                  ],
                ),
              ),
            ),
            if (_dispensary != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _dispensary = null),
                  child: const Text('Clear', style: TextStyle(color: C.muted, fontSize: 12)),
                ),
              ),

            const SizedBox(height: 20),
            _label('Notes (optional)'),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _dec('Terpene notes, appearance, anything memorable…'),
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
                    : const Text('Save Strain', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String? Function(T)? subtitleOf;
  final T? selected;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    this.subtitleOf,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(title, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const Divider(height: 1, color: C.border),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final isSel = item == selected;
                return ListTile(
                  title: Text(labelOf(item), style: TextStyle(color: C.text, fontWeight: isSel ? FontWeight.w600 : FontWeight.normal)),
                  subtitle: subtitleOf != null && subtitleOf!(item) != null
                      ? Text(subtitleOf!(item)!, style: const TextStyle(color: C.muted, fontSize: 13))
                      : null,
                  trailing: isSel ? const Icon(Icons.check, color: C.accent) : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
