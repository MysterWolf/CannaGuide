import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../db/models/dispensary_profile.dart';
import '../../providers/dispensary_profiles_provider.dart';
import '../../theme/colors.dart';

const _uuid = Uuid();

const _paymentOptions = ['Cash', 'Debit', 'Credit', 'Dutchie', 'Leafly', 'CanPay'];

const _days = [
  ('monday', 'Monday'),
  ('tuesday', 'Tuesday'),
  ('wednesday', 'Wednesday'),
  ('thursday', 'Thursday'),
  ('friday', 'Friday'),
  ('saturday', 'Saturday'),
  ('sunday', 'Sunday'),
];

class AddEditProfileScreen extends StatefulWidget {
  final String dispensaryId;
  const AddEditProfileScreen({super.key, required this.dispensaryId});

  @override
  State<AddEditProfileScreen> createState() => _AddEditProfileScreenState();
}

class _AddEditProfileScreenState extends State<AddEditProfileScreen> {
  final _aboutCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _leaflyCtrl = TextEditingController();
  final _dutchieCtrl = TextEditingController();
  final _otherUrlCtrl = TextEditingController();
  final _platformCtrl = TextEditingController();
  final Map<String, TextEditingController> _hoursCtrl = {
    for (final d in _days) d.$1: TextEditingController(),
  };

  List<String> _paymentMethods = [];
  bool _blackOwned = false;
  bool _womanOwned = false;
  bool _lgbtqFriendly = false;
  bool _veteranOwned = false;
  List<Map<String, dynamic>> _specials = [];

  DispensaryProfile? _existing;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await context.read<DispensaryProfilesProvider>().load(widget.dispensaryId);
    if (p != null && mounted) {
      _existing = p;
      _aboutCtrl.text = p.about ?? '';
      _websiteCtrl.text = p.website ?? '';
      _instagramCtrl.text = p.instagram ?? '';
      _leaflyCtrl.text = p.leaflyUrl ?? '';
      _dutchieCtrl.text = p.dutchieUrl ?? '';
      _otherUrlCtrl.text = p.otherOrderingUrl ?? '';
      _platformCtrl.text = p.orderingPlatform ?? '';
      final hm = p.hoursMap;
      for (final d in _days) {
        _hoursCtrl[d.$1]!.text = hm[d.$1] ?? '';
      }
      setState(() {
        _paymentMethods = List<String>.from(p.paymentList);
        _blackOwned = p.blackOwned == 1;
        _womanOwned = p.womanOwned == 1;
        _lgbtqFriendly = p.lgbtqFriendly == 1;
        _veteranOwned = p.veteranOwned == 1;
        _specials = List<Map<String, dynamic>>.from(p.specialsList);
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _aboutCtrl.dispose();
    _websiteCtrl.dispose();
    _instagramCtrl.dispose();
    _leaflyCtrl.dispose();
    _dutchieCtrl.dispose();
    _otherUrlCtrl.dispose();
    _platformCtrl.dispose();
    for (final c in _hoursCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final hoursMap = {
      for (final d in _days)
        if (_hoursCtrl[d.$1]!.text.trim().isNotEmpty) d.$1: _hoursCtrl[d.$1]!.text.trim(),
    };
    final profile = DispensaryProfile(
      id: _existing?.id ?? _uuid.v4(),
      dispensaryId: widget.dispensaryId,
      about: _aboutCtrl.text.trim().isEmpty ? null : _aboutCtrl.text.trim(),
      hours: hoursMap.isEmpty ? null : jsonEncode(hoursMap),
      website: _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      instagram: _instagramCtrl.text.trim().isEmpty ? null : _instagramCtrl.text.trim(),
      leaflyUrl: _leaflyCtrl.text.trim().isEmpty ? null : _leaflyCtrl.text.trim(),
      dutchieUrl: _dutchieCtrl.text.trim().isEmpty ? null : _dutchieCtrl.text.trim(),
      otherOrderingUrl: _otherUrlCtrl.text.trim().isEmpty ? null : _otherUrlCtrl.text.trim(),
      orderingPlatform: _platformCtrl.text.trim().isEmpty ? null : _platformCtrl.text.trim(),
      paymentMethods: _paymentMethods.isEmpty ? null : jsonEncode(_paymentMethods),
      blackOwned: _blackOwned ? 1 : 0,
      womanOwned: _womanOwned ? 1 : 0,
      lgbtqFriendly: _lgbtqFriendly ? 1 : 0,
      veteranOwned: _veteranOwned ? 1 : 0,
      specials: _specials.isEmpty ? null : jsonEncode(_specials),
      dateUpdated: DateTime.now().millisecondsSinceEpoch,
    );
    await context.read<DispensaryProfilesProvider>().save(profile);
    if (mounted) context.pop();
  }

  void _addSpecial() async {
    final itemCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? item;
    String? desc;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        title: const Text('Add Special', style: TextStyle(color: C.text, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'e.g. 20% off edibles today'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(hintText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: C.muted)),
          ),
          TextButton(
            onPressed: () {
              item = itemCtrl.text.trim();
              desc = descCtrl.text.trim();
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: C.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    itemCtrl.dispose();
    descCtrl.dispose();

    if (item != null && item!.isNotEmpty) {
      setState(() {
        _specials.add({
          'item': item!,
          'description': desc ?? '',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator(color: C.accent)),
      );
    }

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: Text(
          _existing != null ? 'Edit Profile' : 'Add Profile',
          style: const TextStyle(color: C.text, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              'Save',
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
            // About
            _label('About'),
            const SizedBox(height: 6),
            TextField(
              controller: _aboutCtrl,
              maxLines: 4,
              decoration: _dec('Tell people about this spot…'),
            ),

            const SizedBox(height: 24),

            // Community badges
            _label('Community badges'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BadgeChip(
                  label: 'Black-Owned',
                  selected: _blackOwned,
                  onTap: () => setState(() => _blackOwned = !_blackOwned),
                ),
                _BadgeChip(
                  label: 'Woman-Owned',
                  selected: _womanOwned,
                  onTap: () => setState(() => _womanOwned = !_womanOwned),
                ),
                _BadgeChip(
                  label: 'LGBTQ+ Friendly',
                  selected: _lgbtqFriendly,
                  onTap: () => setState(() => _lgbtqFriendly = !_lgbtqFriendly),
                ),
                _BadgeChip(
                  label: 'Veteran-Owned',
                  selected: _veteranOwned,
                  onTap: () => setState(() => _veteranOwned = !_veteranOwned),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Payment methods
            _label('Payment methods'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paymentOptions.map((opt) {
                final sel = _paymentMethods.contains(opt);
                return FilterChip(
                  label: Text(opt),
                  selected: sel,
                  onSelected: (v) => setState(() {
                    if (v) _paymentMethods.add(opt);
                    else _paymentMethods.remove(opt);
                  }),
                  selectedColor: C.accentLight,
                  checkmarkColor: C.accent,
                  side: BorderSide(color: sel ? C.accent : C.border),
                  labelStyle: TextStyle(
                    color: sel ? C.accent : C.muted,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Hours
            _label('Hours'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.border),
              ),
              child: Column(
                children: _days.asMap().entries.map((entry) {
                  final i = entry.key;
                  final d = entry.value;
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 1, color: C.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              child: Text(
                                d.$2,
                                style: const TextStyle(
                                  color: C.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _hoursCtrl[d.$1],
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 10am–8pm',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: C.border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: C.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: C.accent),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Specials
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('Specials'),
                TextButton.icon(
                  onPressed: _addSpecial,
                  icon: const Icon(Icons.add, size: 16, color: C.accent),
                  label: const Text('Add', style: TextStyle(color: C.accent, fontSize: 13)),
                ),
              ],
            ),
            if (_specials.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: const Text(
                  'No specials — add deals, daily discounts, or events.',
                  style: TextStyle(color: C.light, fontSize: 13),
                ),
              )
            else
              ..._specials.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['item'] as String? ?? '',
                              style: const TextStyle(
                                color: C.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if ((s['description'] as String? ?? '').isNotEmpty)
                              Text(
                                s['description'] as String,
                                style: const TextStyle(color: C.muted, fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _specials.removeAt(i)),
                        child: const Icon(Icons.close, size: 16, color: C.light),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Links & Ordering
            _label('Links & Ordering'),
            const SizedBox(height: 8),
            TextField(controller: _websiteCtrl, decoration: _dec('Website URL')),
            const SizedBox(height: 10),
            TextField(
              controller: _instagramCtrl,
              decoration: _dec('Instagram handle or URL'),
            ),
            const SizedBox(height: 10),
            TextField(controller: _leaflyCtrl, decoration: _dec('Leafly URL')),
            const SizedBox(height: 10),
            TextField(controller: _dutchieCtrl, decoration: _dec('Dutchie URL')),
            const SizedBox(height: 10),
            TextField(controller: _otherUrlCtrl, decoration: _dec('Other ordering URL')),
            const SizedBox(height: 10),
            TextField(
              controller: _platformCtrl,
              decoration: _dec('Ordering platform (e.g. Dutchie, IHeartJane)'),
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _existing != null ? 'Save Changes' : 'Save Profile',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14),
      );

  InputDecoration _dec(String hint) => InputDecoration(hintText: hint);
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BadgeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? C.goldLight : C.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? C.gold : C.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.star, size: 13, color: C.gold),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? C.amber : C.muted,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
}
