import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../db/models/dispensary.dart';
import '../../db/models/session.dart';
import '../../db/models/strain.dart';
import '../../providers/dispensaries_provider.dart';
import '../../providers/sessions_provider.dart';
import '../../providers/strains_provider.dart';
import '../../theme/colors.dart';

const _uuid = Uuid();

const _categories = ['Flower', 'Edible', 'Vape', 'Beverage', 'Tincture', 'Topical', 'Concentrate'];
const _timesOfDay = ['Morning', 'Afternoon', 'Evening', 'Night'];
const _settings = ['Home', 'Social', 'Work', 'Outdoors', 'Medical'];

class LogSessionScreen extends StatefulWidget {
  final String? preloadStrainId;
  const LogSessionScreen({super.key, this.preloadStrainId});

  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  Strain? _strain;
  Dispensary? _dispensary;
  String? _category;
  String? _timeOfDay;
  String? _setting;
  int? _overallRating;
  final _notesCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  bool _saving = false;

  // Effect sliders — null means user hasn't set them
  final Map<String, double?> _effects = {
    'focus': null,
    'sleep': null,
    'anxiety': null,
    'pain': null,
    'mood': null,
    'creativity': null,
    'energy': null,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<StrainsProvider>().load();
      context.read<DispensariesProvider>().load();
      if (widget.preloadStrainId != null) {
        final strains = context.read<StrainsProvider>().strains;
        final match = strains.cast<Strain?>().firstWhere(
          (s) => s?.id == widget.preloadStrainId,
          orElse: () => null,
        );
        if (match != null && mounted) setState(() => _strain = match);
      }
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final session = Session(
      id: _uuid.v4(),
      strainId: _strain?.id,
      dispensaryId: _dispensary?.id,
      sessionAt: DateTime.now().toIso8601String(),
      productCategory: _category,
      timeOfDay: _timeOfDay,
      setting: _setting,
      overallRating: _overallRating,
      effectFocus: _effects['focus']?.round(),
      effectSleep: _effects['sleep']?.round(),
      effectAnxiety: _effects['anxiety']?.round(),
      effectPain: _effects['pain']?.round(),
      effectMood: _effects['mood']?.round(),
      effectCreativity: _effects['creativity']?.round(),
      effectEnergy: _effects['energy']?.round(),
      durationMins: int.tryParse(_durationCtrl.text.trim()),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    await context.read<SessionsProvider>().add(session);
    if (mounted) context.pop();
  }

  void _pickStrain() async {
    final strains = context.read<StrainsProvider>().strains;
    if (strains.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No strains yet. Add one first.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Strain>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => _StrainPickerSheet(
          strains: strains,
          selected: _strain,
          scrollController: ctrl,
        ),
      ),
    );
    if (picked != null) setState(() => _strain = picked);
  }

  void _pickDispensary() async {
    final dispensaries = context.read<DispensariesProvider>().dispensaries;
    if (dispensaries.isEmpty) return;
    final picked = await showModalBottomSheet<Dispensary>(
      context: context,
      builder: (ctx) => _SimplePickerSheet<Dispensary>(
        title: 'Dispensary',
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
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('Log Session', style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
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
            // Strain picker
            _label('Strain'),
            const SizedBox(height: 6),
            _PickerRow(
              icon: Icons.local_florist_outlined,
              text: _strain?.name ?? 'Select strain (optional)',
              set: _strain != null,
              onTap: _pickStrain,
              onClear: _strain != null ? () => setState(() => _strain = null) : null,
            ),

            const SizedBox(height: 16),
            _label('Dispensary'),
            const SizedBox(height: 6),
            _PickerRow(
              icon: Icons.storefront_outlined,
              text: _dispensary?.name ?? 'Select dispensary (optional)',
              set: _dispensary != null,
              onTap: _pickDispensary,
              onClear: _dispensary != null ? () => setState(() => _dispensary = null) : null,
            ),

            const SizedBox(height: 20),
            _label('Category'),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Time of day'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _timesOfDay.map((t) {
                          final sel = t == _timeOfDay;
                          return ChoiceChip(
                            label: Text(t),
                            selected: sel,
                            onSelected: (_) => setState(() => _timeOfDay = sel ? null : t),
                            selectedColor: C.accentLight,
                            side: BorderSide(color: sel ? C.accent : C.border),
                            labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _label('Setting'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _settings.map((s) {
                final sel = s == _setting;
                return ChoiceChip(
                  label: Text(s),
                  selected: sel,
                  onSelected: (_) => setState(() => _setting = sel ? null : s),
                  selectedColor: C.accentLight,
                  side: BorderSide(color: sel ? C.accent : C.border),
                  labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            _label('Overall rating'),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                final filled = _overallRating != null && i < _overallRating!;
                return GestureDetector(
                  onTap: () => setState(() => _overallRating = (_overallRating == i + 1) ? null : i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      size: 36,
                      color: C.gold,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Effects (optional)'),
                TextButton(
                  onPressed: () => setState(() => _effects.updateAll((k, v) => null)),
                  child: const Text('Clear all', style: TextStyle(color: C.muted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ..._effects.keys.map((key) => _EffectRow(
                  label: key[0].toUpperCase() + key.substring(1),
                  value: _effects[key],
                  onChanged: (v) => setState(() => _effects[key] = v),
                )),

            const SizedBox(height: 20),
            _label('Duration (minutes)'),
            const SizedBox(height: 6),
            TextField(
              controller: _durationCtrl,
              keyboardType: TextInputType.number,
              decoration: _dec('e.g. 90'),
            ),

            const SizedBox(height: 20),
            _label('Notes'),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: _dec('How did it go?'),
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
                    : const Text('Save Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool set;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _PickerRow({
    required this.icon,
    required this.text,
    required this.set,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: set ? C.accent : C.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: set ? C.accent : C.light),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: set ? C.text : C.light))),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 16, color: C.muted),
              )
            else
              const Icon(Icons.chevron_right, color: C.light, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EffectRow extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  const _EffectRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isSet = value != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: isSet ? C.text : C.muted, fontSize: 14)),
          ),
          Expanded(
            child: Slider(
              value: value ?? 5.0,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: isSet ? C.accent : C.border,
              inactiveColor: C.border,
              onChangeStart: (_) {
                if (!isSet) onChanged(5.0);
              },
              onChanged: (v) => onChanged(v),
            ),
          ),
          SizedBox(
            width: 28,
            child: isSet
                ? Text(value!.round().toString(), style: const TextStyle(color: C.accent, fontWeight: FontWeight.w600, fontSize: 14))
                : GestureDetector(
                    onTap: () => onChanged(5.0),
                    child: const Icon(Icons.add_circle_outline, size: 20, color: C.border),
                  ),
          ),
          if (isSet)
            GestureDetector(
              onTap: () => onChanged(null),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.close, size: 16, color: C.muted),
              ),
            )
          else
            const SizedBox(width: 20),
        ],
      ),
    );
  }
}

class _StrainPickerSheet extends StatefulWidget {
  final List<Strain> strains;
  final Strain? selected;
  final ScrollController scrollController;

  const _StrainPickerSheet({
    required this.strains,
    required this.selected,
    required this.scrollController,
  });

  @override
  State<_StrainPickerSheet> createState() => _StrainPickerSheetState();
}

class _StrainPickerSheetState extends State<_StrainPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.strains
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Text('Select strain', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search strains…',
              prefixIcon: const Icon(Icons.search, color: C.muted),
              filled: true,
              fillColor: C.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.accent)),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: C.border),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final s = filtered[i];
              final isSel = s.id == widget.selected?.id;
              final typeColor = switch (s.strainType?.toLowerCase()) {
                'sativa' => C.sage,
                'indica' => C.danger,
                _ => C.amber,
              };
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.local_florist, color: typeColor, size: 18),
                ),
                title: Text(s.name, style: TextStyle(color: C.text, fontWeight: isSel ? FontWeight.w600 : FontWeight.normal)),
                subtitle: s.brand != null && s.brand!.isNotEmpty
                    ? Text(s.brand!, style: const TextStyle(color: C.muted, fontSize: 13))
                    : null,
                trailing: isSel ? const Icon(Icons.check, color: C.accent) : null,
                onTap: () => Navigator.pop(context, s),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SimplePickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String? Function(T)? subtitleOf;
  final T? selected;

  const _SimplePickerSheet({
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
