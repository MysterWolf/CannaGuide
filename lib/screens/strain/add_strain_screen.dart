import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config.dart';
import '../../db/database.dart';
import '../../db/models/dispensary.dart';
import '../../db/models/strain.dart';
import '../../providers/dispensaries_provider.dart';
import '../../providers/strains_provider.dart';
import '../../services/device_id_service.dart';
import '../../theme/colors.dart';

const _uuid = Uuid();

// Canonical category list — must match log_session_screen.dart
const _strainCategories = [
  'Flower', 'Pre-Roll', 'Vape', 'Concentrate',
  'Edible', 'Tincture', 'Topical', 'Shots & Nano', 'Other',
];
const _strainTypes = ['sativa', 'indica', 'hybrid'];

class AddStrainScreen extends StatefulWidget {
  final String? strainId;
  const AddStrainScreen({super.key, this.strainId});

  bool get isEditing => strainId != null;

  @override
  State<AddStrainScreen> createState() => _AddStrainScreenState();
}

class _AddStrainScreenState extends State<AddStrainScreen> {
  final _nameCtrl  = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _strainType = 'hybrid';
  String? _category;
  Dispensary? _dispensary;
  bool _saving = false;
  bool _loading = false;
  Strain? _existing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<DispensariesProvider>().load();
      if (widget.isEditing) await _loadExisting();
    });
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final strain = await AppDatabase.getStrain(widget.strainId!);
    if (strain == null || !mounted) {
      setState(() => _loading = false);
      return;
    }
    _existing = strain;
    _nameCtrl.text  = strain.name;
    _brandCtrl.text = strain.brand ?? '';
    _notesCtrl.text = strain.notes ?? '';

    // Match stored strainType to one of the valid options
    final type = strain.strainType?.toLowerCase();
    final validTypes = ['sativa', 'indica', 'hybrid'];

    Dispensary? disp;
    if (strain.dispensaryId != null) {
      disp = context.read<DispensariesProvider>().dispensaries
          .cast<Dispensary?>()
          .firstWhere((d) => d?.id == strain.dispensaryId, orElse: () => null);
      disp ??= await AppDatabase.getDispensary(strain.dispensaryId!);
    }

    setState(() {
      _strainType = validTypes.contains(type) ? type! : 'hybrid';
      _category   = _strainCategories.contains(strain.category) ? strain.category : null;
      _dispensary = disp;
      _loading    = false;
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

    final strain = Strain(
      id: _existing?.id ?? _uuid.v4(),
      name: name,
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      strainType: _strainType,
      source: _existing?.source ?? 'manual',
      sourceType: _existing?.sourceType,
      createdAt: _existing?.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
      thcPct: _existing?.thcPct,
      cbdPct: _existing?.cbdPct,
      terpeneProfile: _existing?.terpeneProfile,
      cannabinoidProfile: _existing?.cannabinoidProfile,
      description: _existing?.description,
      category: _category,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      dispensaryId: _dispensary?.id,
      stashpassStrainId: _existing?.stashpassStrainId,
    );

    if (widget.isEditing) {
      await context.read<StrainsProvider>().update(strain);
    } else {
      await context.read<StrainsProvider>().add(strain);
      if (strain.stashpassStrainId == null && mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final provider   = context.read<StrainsProvider>();
        _queueSubmit(strain, messenger, provider);
      }
    }
    if (mounted) context.pop();
  }

  void _queueSubmit(
    Strain strain,
    ScaffoldMessengerState messenger,
    StrainsProvider provider,
  ) {
    Future.microtask(() async {
      try {
        final res = await http
            .post(
              Uri.parse('$kCirclesApiBase/queue/strains'),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'name': strain.name,
                if (strain.strainType != null) 'type': strain.strainType,
                'device_id': DeviceIdService.deviceId,
              }),
            )
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          if (data['status'] == 'exists') {
            final sid = data['strain_id'] as String?;
            if (sid != null) {
              await provider.update(strain.copyWith(stashpassStrainId: sid));
              messenger.showSnackBar(
                const SnackBar(content: Text('Matched to StashPass database')),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[Queue] Submit failed: $e');
      }
    });
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
      backgroundColor: C.surface,
      builder: (ctx) => _PickerSheet<Dispensary>(
        title: 'Source dispensary',
        items: dispensaries,
        labelOf: (d) => d.name,
        selected: _dispensary,
      ),
    );
    if (picked != null) setState(() => _dispensary = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator(color: C.accent)),
      );
    }

    final typeColor = switch (_strainType) {
      'sativa' => C.sage,
      'indica' => C.danger,
      _ => C.amber,
    };

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: Text(
          widget.isEditing ? 'Edit Strain' : 'Add Strain',
          style: const TextStyle(color: C.text, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              widget.isEditing ? 'Update' : 'Save',
              style: TextStyle(color: _saving ? C.muted : C.accent, fontWeight: FontWeight.w700),
            ),
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
              autofocus: !widget.isEditing,
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
              children: _strainCategories.map((c) {
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
                        _dispensary == null ? 'Select dispensary' : _dispensary!.name,
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
                    : Text(
                        widget.isEditing ? 'Update Strain' : 'Save Strain',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14));

  InputDecoration _dec(String hint) => InputDecoration(hintText: hint);
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
