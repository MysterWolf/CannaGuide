import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config.dart';
import '../../db/database.dart';
import '../../db/models/dispensary.dart';
import '../../db/models/session.dart';
import '../../db/models/strain.dart';
import '../../providers/dispensaries_provider.dart';
import '../../providers/sessions_provider.dart';
import '../../providers/strains_provider.dart';
import '../../services/device_id_service.dart';
import '../../theme/colors.dart';

const _uuid = Uuid();

// Canonical list — must match add_strain_screen.dart
const _categories = ['Flower', 'Pre-Roll', 'Vape', 'Concentrate', 'Edible', 'Tincture', 'Topical', 'Shots & Nano', 'Other'];
const _timesOfDay = ['Morning', 'Afternoon', 'Evening', 'Night'];
const _settings = ['Home', 'Social', 'Work', 'Outdoors', 'Medical'];
const _sourceTypes = ['Dispensary', 'Wellness Retail', 'Smoke Shop', 'Liquor Store', 'General Retail'];
const _functionalIngredientOptions = ["Lion's Mane", 'CBN', 'CBD', 'Cordyceps', 'Caffeine'];
const _useCaseOptions = ['Social', 'Sleep', 'Focus', 'Relax', 'Energy'];
const _shotsUseCaseOptions = ['Social', 'Focus', 'Relax', 'Energy'];
const _shotTypeOptions = ['Standard Shot', 'Nano-Emulsified'];
const _ratingLabels = ['Poor', 'Low', 'OK', 'Good', 'Great'];
const _showMgCategories = {'Edible', 'Tincture', 'Shots & Nano'};
const _methodsByCategory = {
  // Pre-Roll as method = you rolled or used a pre-roll of loose flower
  'Flower':      ['Joint', 'Pipe', 'Bong', 'Vaporizer', 'Pre-Roll', 'Dab Rig', 'Dab Pen', 'Nectar Collector'],
  'Vape':        ['Cartridge', 'Disposable', 'Pod'],
  'Concentrate': ['Dab Rig', 'Dab Pen', 'Nectar Collector'],
};

// Case-insensitive chip match; handles underscore spacing ('smoke_shop' → 'Smoke Shop'),
// plurals ('edibles' → 'Edible'), and prefix truncation ('outdoor' → 'Outdoors').
String? _matchChip(String? raw, List<String> options) {
  if (raw == null) return null;
  final normalized = raw.toLowerCase().replaceAll('_', ' ');
  for (final o in options) {
    if (o.toLowerCase() == normalized) return o;
  }
  for (final o in options) {
    final lower = o.toLowerCase();
    if (normalized.startsWith(lower) || lower.startsWith(normalized)) return o;
  }
  return null;
}

String _formatNum(double? v) {
  if (v == null) return '';
  return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

// ─────────────────────────────────────────────────────────────────────────────

class LogSessionScreen extends StatefulWidget {
  final String? preloadStrainId;
  final String? sessionId;

  const LogSessionScreen({super.key, this.preloadStrainId, this.sessionId});

  bool get isEditing => sessionId != null;

  @override
  State<LogSessionScreen> createState() => _LogSessionScreenState();
}

class _LogSessionScreenState extends State<LogSessionScreen> {
  // ── Section expansion ─────────────────────────────────────────────────────
  bool _whatExpanded     = true;
  bool _doseExpanded     = false;
  bool _beverageExpanded = false;
  bool _effectsExpanded  = false;
  bool _notesExpanded    = true;

  // ── Section 1: What ───────────────────────────────────────────────────────
  final _strainNameCtrl = TextEditingController();
  final _brandCtrl      = TextEditingController();
  String? _category;
  String? _method;
  String? _sourceType;
  Dispensary? _dispensary;

  // ── Section 2: Dose ───────────────────────────────────────────────────────
  final _doseNotesCtrl = TextEditingController();
  final _mgThcCtrl     = TextEditingController();
  final _mgCbdCtrl     = TextEditingController();
  final _onsetCtrl     = TextEditingController();
  final _durationCtrl  = TextEditingController();

  // ── Section 3: Beverage / Shot extras ────────────────────────────────────
  List<String> _functionalIngredients = [];
  String? _useCase;
  String? _productType;

  // ── Section 4: Effects ────────────────────────────────────────────────────
  String? _timeOfDay;
  String? _setting;
  int? _overallRating;
  final Map<String, double?> _effects = {
    'focus': null, 'sleep': null, 'anxiety': null,
    'pain': null, 'mood': null, 'creativity': null, 'energy': null,
  };
  bool _sideDryMouth = false;
  bool _sideParanoia = false;
  bool _sideHeadache = false;
  bool _sideAnxiety  = false;
  String? _couchLockIntent;
  String? _hungerIntent;

  // ── Section 5: Notes ──────────────────────────────────────────────────────
  final _notesCtrl = TextEditingController();

  // ── Misc ──────────────────────────────────────────────────────────────────
  bool _saving = false;
  bool _loadingSession = false;
  Session? _existingSession;

  // ── Section summaries ─────────────────────────────────────────────────────

  String get _whatSummary {
    final parts = <String>[];
    final name = _strainNameCtrl.text.trim();
    if (name.isNotEmpty) parts.add(name);
    if (_category != null) parts.add(_category!);
    if (_method != null) parts.add(_method!);
    if (_sourceType != null) parts.add('from $_sourceType');
    return parts.join(' · ');
  }

  String get _doseSummary {
    final parts = <String>[];
    if (_mgThcCtrl.text.trim().isNotEmpty) parts.add('${_mgThcCtrl.text.trim()}mg THC');
    if (_mgCbdCtrl.text.trim().isNotEmpty) parts.add('${_mgCbdCtrl.text.trim()}mg CBD');
    final dn = _doseNotesCtrl.text.trim();
    if (dn.isNotEmpty) parts.add(dn.length > 30 ? '${dn.substring(0, 30)}…' : dn);
    if (_onsetCtrl.text.trim().isNotEmpty) parts.add('onset ${_onsetCtrl.text.trim()} min');
    if (_durationCtrl.text.trim().isNotEmpty) parts.add('${_durationCtrl.text.trim()} min');
    return parts.join(' · ');
  }

  String get _beverageSummary {
    final parts = <String>[];
    if (_productType != null) parts.add(_productType!);
    if (_functionalIngredients.isNotEmpty) parts.add(_functionalIngredients.join(', '));
    if (_useCase != null) parts.add(_useCase!);
    return parts.join(' · ');
  }

  String get _effectsSummary {
    final parts = <String>[];
    if (_timeOfDay != null) parts.add(_timeOfDay!);
    if (_setting != null) parts.add(_setting!);
    if (_overallRating != null) {
      final r = _overallRating!.clamp(1, _ratingLabels.length);
      parts.add('${'★' * r} ${_ratingLabels[r - 1]}');
    }
    final setCount = _effects.values.where((v) => v != null).length;
    if (setCount > 0) parts.add('$setCount effects');
    if (_sideDryMouth) parts.add('Dry Mouth');
    if (_sideParanoia) parts.add('Paranoia');
    if (_sideHeadache) parts.add('Headache');
    if (_sideAnxiety) parts.add('Anxiety');
    return parts.join(' · ');
  }

  String get _notesSummary {
    final t = _notesCtrl.text.trim();
    if (t.isEmpty) return '';
    return t.length > 50 ? '${t.substring(0, 50)}…' : t;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<StrainsProvider>().load();
      await context.read<DispensariesProvider>().load();

      if (widget.sessionId != null) {
        setState(() => _loadingSession = true);
        await _loadExistingSession(widget.sessionId!);
      } else if (widget.preloadStrainId != null) {
        final strains = context.read<StrainsProvider>().strains;
        final match = strains.cast<Strain?>().firstWhere(
          (s) => s?.id == widget.preloadStrainId,
          orElse: () => null,
        );
        if (match != null && mounted) setState(() => _strainNameCtrl.text = match.name);
      }
    });
  }

  Future<void> _loadExistingSession(String id) async {
    final session = await AppDatabase.getSession(id);
    if (session == null || !mounted) {
      setState(() => _loadingSession = false);
      return;
    }
    _existingSession = session;

    Strain? strain;
    if (session.strainId != null) {
      strain = await AppDatabase.getStrain(session.strainId!);
      if (strain != null && mounted) {
        _strainNameCtrl.text = strain.name;
        _brandCtrl.text = strain.brand ?? '';
        _sourceType = _matchChip(strain.sourceType, _sourceTypes);
      }
    }

    if (session.dispensaryId != null) {
      _dispensary = await AppDatabase.getDispensary(session.dispensaryId!);
    }

    if (!mounted) return;

    final methods = _methodsByCategory[_matchChip(session.productCategory, _categories)] ?? [];

    setState(() {
      _category    = _matchChip(session.productCategory, _categories);
      _method      = _matchChip(session.method, methods.isEmpty ? _methodsByCategory.values.expand((v) => v).toList() : methods);
      _timeOfDay   = _matchChip(session.timeOfDay, _timesOfDay);
      _setting     = _matchChip(session.setting, _settings);
      _overallRating = session.overallRating?.clamp(1, 5);

      _effects['focus']      = session.effectFocus?.toDouble();
      _effects['sleep']      = session.effectSleep?.toDouble();
      _effects['anxiety']    = session.effectAnxiety?.toDouble();
      _effects['pain']       = session.effectPain?.toDouble();
      _effects['mood']       = session.effectMood?.toDouble();
      _effects['creativity'] = session.effectCreativity?.toDouble();
      _effects['energy']     = session.effectEnergy?.toDouble();

      _doseNotesCtrl.text = session.doseNotes ?? '';
      _mgThcCtrl.text     = _formatNum(session.mgThc);
      _mgCbdCtrl.text     = _formatNum(session.mgCbd);
      if (session.onsetMins != null) _onsetCtrl.text = session.onsetMins.toString();
      if (session.durationMins != null) _durationCtrl.text = session.durationMins.toString();

      // Functional ingredients (stored as comma-separated)
      final fi = session.functionalIngredients;
      if (fi != null && fi.isNotEmpty && !fi.startsWith('[')) {
        _functionalIngredients = fi.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
      _useCase = _matchChip(session.useCase, _useCaseOptions);
      _productType = session.productType;

      _sideDryMouth = session.sideDryMouth == 1;
      _sideParanoia = session.sideParanoia == 1;
      _sideHeadache = session.sideHeadache == 1;
      _sideAnxiety  = session.sideAnxiety == 1;

      _couchLockIntent = _matchChip(session.couchLockIntent, ['Wanted', 'Just Noticed', 'Unwanted']);
      _hungerIntent    = _matchChip(session.hungerIntent,    ['Wanted', 'Just Noticed', 'Unwanted']);

      _notesCtrl.text = session.notes ?? '';

      // Auto-expand sections that have data
      _doseExpanded     = _doseNotesCtrl.text.isNotEmpty || _mgThcCtrl.text.isNotEmpty ||
                          _mgCbdCtrl.text.isNotEmpty || _onsetCtrl.text.isNotEmpty;
      _beverageExpanded = _functionalIngredients.isNotEmpty || _useCase != null || _productType != null;
      _effectsExpanded  = _overallRating != null || _effects.values.any((v) => v != null) ||
                          _sideDryMouth || _sideParanoia || _sideHeadache || _sideAnxiety ||
                          _timeOfDay != null || _setting != null;
      _notesExpanded    = _notesCtrl.text.isNotEmpty;

      _loadingSession = false;
    });
  }

  @override
  void dispose() {
    _strainNameCtrl.dispose();
    _brandCtrl.dispose();
    _doseNotesCtrl.dispose();
    _mgThcCtrl.dispose();
    _mgCbdCtrl.dispose();
    _onsetCtrl.dispose();
    _durationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Save / Delete ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);

    Strain? resolvedStrain;
    String? strainId;
    final strainName = _strainNameCtrl.text.trim();
    if (strainName.isNotEmpty) {
      final strains = context.read<StrainsProvider>().strains;
      final existing = strains.cast<Strain?>().firstWhere(
        (s) => s!.name.toLowerCase() == strainName.toLowerCase(),
        orElse: () => null,
      );
      if (existing != null) {
        strainId = existing.id;
        resolvedStrain = existing;
      } else {
        final newStrain = Strain(
          id: _uuid.v4(),
          name: strainName,
          brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
          sourceType: _sourceType,
          source: 'manual',
        );
        await context.read<StrainsProvider>().add(newStrain);
        strainId = newStrain.id;
        resolvedStrain = newStrain;
      }
    }

    final session = Session(
      id: _existingSession?.id ?? _uuid.v4(),
      strainId: strainId,
      dispensaryId: _dispensary?.id,
      sessionAt: _existingSession?.sessionAt ?? DateTime.now().toIso8601String(),
      createdAt: _existingSession?.createdAt,
      updatedAt: DateTime.now().toIso8601String(),
      productCategory: _category,
      productType: _productType,
      method: _method,
      doseNotes: _doseNotesCtrl.text.trim().isEmpty ? null : _doseNotesCtrl.text.trim(),
      mgThc: double.tryParse(_mgThcCtrl.text.trim()),
      mgCbd: double.tryParse(_mgCbdCtrl.text.trim()),
      onsetMins: int.tryParse(_onsetCtrl.text.trim()),
      durationMins: int.tryParse(_durationCtrl.text.trim()),
      timeOfDay: _timeOfDay,
      setting: _setting,
      overallRating: _overallRating,
      effectFocus:      _effects['focus']?.round(),
      effectSleep:      _effects['sleep']?.round(),
      effectAnxiety:    _effects['anxiety']?.round(),
      effectPain:       _effects['pain']?.round(),
      effectMood:       _effects['mood']?.round(),
      effectCreativity: _effects['creativity']?.round(),
      effectEnergy:     _effects['energy']?.round(),
      functionalIngredients: _functionalIngredients.isEmpty ? null : _functionalIngredients.join(','),
      useCase: _useCase,
      sideDryMouth: _sideDryMouth ? 1 : 0,
      sideParanoia: _sideParanoia ? 1 : 0,
      sideHeadache: _sideHeadache ? 1 : 0,
      sideAnxiety: _sideAnxiety ? 1 : 0,
      couchLockIntent: _couchLockIntent,
      hungerIntent: _hungerIntent,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (widget.isEditing) {
      await context.read<SessionsProvider>().update(session);
    } else {
      await context.read<SessionsProvider>().add(session);
    }

    // Fire queue lookup for any strain not yet linked to StashPass.
    // Covers pre-existing strains (added before queue feature) and strains
    // where admin added the curated version independently.
    if (!widget.isEditing && resolvedStrain != null && resolvedStrain.stashpassStrainId == null && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final provider   = context.read<StrainsProvider>();
      _queueSubmit(resolvedStrain, messenger, provider);
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: const Text('Delete session?'),
        content: const Text('This entry will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SessionsProvider>().delete(_existingSession!.id);
    if (mounted) context.pop();
  }

  // ── Dispensary picker ─────────────────────────────────────────────────────

  void _pickDispensary() async {
    final dispensaries = context.read<DispensariesProvider>().dispensaries;
    if (dispensaries.isEmpty) return;
    final picked = await showModalBottomSheet<Dispensary>(
      context: context,
      backgroundColor: C.surface,
      builder: (ctx) => _SimplePickerSheet<Dispensary>(
        title: 'Select Dispensary',
        items: dispensaries,
        // DISPLAY: always use name, never city
        labelOf: (d) => d.name,
        selected: _dispensary,
      ),
    );
    if (picked != null) setState(() => _dispensary = picked);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingSession) {
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
          widget.isEditing ? 'Edit Entry' : 'Log Session',
          style: const TextStyle(color: C.text, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              widget.isEditing ? 'Update' : 'Save',
              style: TextStyle(
                color: _saving ? C.muted : C.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sections ────────────────────────────────────────────────────
            _CollapsibleSection(
              title: 'What',
              summary: _whatSummary,
              expanded: _whatExpanded,
              onToggle: () => setState(() => _whatExpanded = !_whatExpanded),
              child: _buildWhatSection(),
            ),
            _CollapsibleSection(
              title: 'Dose',
              summary: _doseSummary,
              expanded: _doseExpanded,
              onToggle: () => setState(() => _doseExpanded = !_doseExpanded),
              child: _buildDoseSection(),
            ),
            if (_category == 'Shots & Nano')
              _CollapsibleSection(
                title: 'Shot Details',
                summary: _beverageSummary,
                expanded: _beverageExpanded,
                onToggle: () => setState(() => _beverageExpanded = !_beverageExpanded),
                child: _buildBeverageSection(),
              ),
            _CollapsibleSection(
              title: 'Effects',
              summary: _effectsSummary,
              expanded: _effectsExpanded,
              onToggle: () => setState(() => _effectsExpanded = !_effectsExpanded),
              child: _buildEffectsSection(),
            ),
            _CollapsibleSection(
              title: 'Notes',
              summary: _notesSummary,
              expanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
              child: _buildNotesSection(),
            ),
            const Divider(height: 1, color: C.border),
            const SizedBox(height: 24),

            // ── Save ────────────────────────────────────────────────────────
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
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        widget.isEditing ? 'Update Session' : 'Save Session',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            // ── Delete (edit mode only) ──────────────────────────────────────
            if (widget.isEditing) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saving ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: C.danger,
                    side: const BorderSide(color: C.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Delete Session',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section 1: What ───────────────────────────────────────────────────────

  Widget _buildWhatSection() {
    final methods = _category != null ? (_methodsByCategory[_category] ?? []) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strain
        _label('Strain (optional)'),
        const SizedBox(height: 6),
        _StrainField(controller: _strainNameCtrl, onChanged: () => setState(() {})),

        const SizedBox(height: 16),

        // Brand
        _label('Brand (optional)'),
        const SizedBox(height: 6),
        TextField(
          controller: _brandCtrl,
          decoration: _dec('e.g. Cookies, Stiiizy, Kiva'),
        ),

        const SizedBox(height: 20),

        // Category
        _label('Category'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _categories.map((c) {
            final sel = c == _category;
            final chipLabel = c == 'Shots & Nano' ? '⚡ $c' : c;
            return ChoiceChip(
              label: Text(chipLabel),
              selected: sel,
              onSelected: (_) => setState(() {
                _category = sel ? null : c;
                // Clear method if new category has different options
                if (_method != null) {
                  final newMethods = _methodsByCategory[_category] ?? [];
                  if (!newMethods.contains(_method)) _method = null;
                }
                // Clear product type if switching away from Shots & Nano
                if (_category != 'Shots & Nano') _productType = null;
                // Auto-expand extras section for Shots & Nano
                if (_category == 'Shots & Nano') _beverageExpanded = true;
              }),
              selectedColor: C.accentLight,
              side: BorderSide(color: sel ? C.accent : C.border),
              labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
            );
          }).toList(),
        ),

        // Method — only for Flower, Vape, Concentrate
        if (methods.isNotEmpty) ...[
          const SizedBox(height: 20),
          _label('Method'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: methods.map((m) {
              final sel = m == _method;
              return ChoiceChip(
                label: Text(m),
                selected: sel,
                onSelected: (_) => setState(() => _method = sel ? null : m),
                selectedColor: C.accentLight,
                side: BorderSide(color: sel ? C.accent : C.border),
                labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 20),

        // Source type
        _label('Where from?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _sourceTypes.map((s) {
            final sel = s == _sourceType;
            return ChoiceChip(
              label: Text(s),
              selected: sel,
              onSelected: (_) => setState(() => _sourceType = sel ? null : s),
              selectedColor: C.accentLight,
              side: BorderSide(color: sel ? C.accent : C.border),
              labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Dispensary picker
        _PickerRow(
          icon: Icons.storefront_outlined,
          text: _dispensary != null
              ? _dispensary!.name
              : 'Pick specific location (optional)',
          set: _dispensary != null,
          onTap: _pickDispensary,
          onClear: _dispensary != null ? () => setState(() => _dispensary = null) : null,
        ),
      ],
    );
  }

  // ── Section 2: Dose ───────────────────────────────────────────────────────

  Widget _buildDoseSection() {
    final showMg = _category != null && _showMgCategories.contains(_category);
    final onsetHint = _category == 'Shots & Nano'
        ? (_productType == 'Nano-Emulsified'
            ? 'min  (nano: 15-30 typical)'
            : _productType == 'Standard Shot'
                ? 'min  (standard: 45-90 typical)'
                : 'min  (15-90 typical for shots)')
        : 'min';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Dose notes'),
        const SizedBox(height: 6),
        TextField(
          controller: _doseNotesCtrl,
          decoration: _dec('e.g. 2 hits, half a gummy, 1 dropper'),
        ),

        if (showMg) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('mg THC'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _mgThcCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec('e.g. 10'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('mg CBD'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _mgCbdCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec('e.g. 5'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Felt it after'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _onsetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec(onsetHint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Lasted about'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _dec('min'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Section 3: Beverage / Shot extras ────────────────────────────────────

  // Only called when _category == 'Shots & Nano'
  Widget _buildBeverageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Product type'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _shotTypeOptions.map((t) {
            final sel = t == _productType;
            return ChoiceChip(
              label: Text(t),
              selected: sel,
              onSelected: (_) => setState(() => _productType = sel ? null : t),
              selectedColor: C.accentLight,
              side: BorderSide(color: sel ? C.accent : C.border),
              labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _label('Use case'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _shotsUseCaseOptions.map((uc) {
            final sel = uc == _useCase;
            return ChoiceChip(
              label: Text(uc),
              selected: sel,
              onSelected: (_) => setState(() => _useCase = sel ? null : uc),
              selectedColor: C.accentLight,
              side: BorderSide(color: sel ? C.accent : C.border),
              labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Section 4: Effects ────────────────────────────────────────────────────

  Widget _buildEffectsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time of day
        _label('When'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
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

        const SizedBox(height: 20),

        // Setting
        _label('Setting'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
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

        const SizedBox(height: 20),

        // Overall rating with label
        _label('Overall rating'),
        const SizedBox(height: 10),
        Row(
          children: [
            ...List.generate(5, (i) {
              final filled = _overallRating != null && i < _overallRating!;
              return GestureDetector(
                onTap: () => setState(
                  () => _overallRating = (_overallRating == i + 1) ? null : i + 1,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 32,
                    color: C.gold,
                  ),
                ),
              );
            }),
            if (_overallRating != null && _overallRating! <= _ratingLabels.length) ...[
              const SizedBox(width: 6),
              Text(
                _ratingLabels[_overallRating! - 1],
                style: const TextStyle(
                  color: C.amber,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 24),

        // Effect sliders
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

        // Side effects
        _label('Side effects'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _sideEffectChip('Dry Mouth', _sideDryMouth, (v) => setState(() => _sideDryMouth = v)),
            _sideEffectChip('Paranoia',  _sideParanoia,  (v) => setState(() => _sideParanoia = v)),
            _sideEffectChip('Headache',  _sideHeadache,  (v) => setState(() => _sideHeadache = v)),
            _sideEffectChip('Anxiety',   _sideAnxiety,   (v) => setState(() => _sideAnxiety = v)),
          ],
        ),

        const SizedBox(height: 20),

        // Couch-lock intent
        _label('Couch-lock'),
        const SizedBox(height: 8),
        _intentRow(_couchLockIntent, (v) => setState(() => _couchLockIntent = v)),

        const SizedBox(height: 20),

        // Hunger intent
        _label('Hunger / munchies'),
        const SizedBox(height: 8),
        _intentRow(_hungerIntent, (v) => setState(() => _hungerIntent = v)),
      ],
    );
  }

  // ── Section 5: Notes ──────────────────────────────────────────────────────

  Widget _buildNotesSection() {
    return TextField(
      controller: _notesCtrl,
      maxLines: 5,
      decoration: _dec('How did it go? What did you notice?'),
    );
  }

  // ── Helper builders ───────────────────────────────────────────────────────

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14),
      );

  InputDecoration _dec(String hint) => InputDecoration(hintText: hint);

  Widget _sideEffectChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      selectedColor: C.dangerLt,
      checkmarkColor: C.danger,
      side: BorderSide(color: selected ? C.danger : C.border),
      labelStyle: TextStyle(color: selected ? C.danger : C.muted, fontSize: 13),
    );
  }

  Widget _intentRow(String? value, ValueChanged<String?> onChanged) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: ['Wanted', 'Just Noticed', 'Unwanted'].map((opt) {
        final sel = opt == value;
        return ChoiceChip(
          label: Text(opt),
          selected: sel,
          onSelected: (_) => onChanged(sel ? null : opt),
          selectedColor: C.accentLight,
          side: BorderSide(color: sel ? C.accent : C.border),
          labelStyle: TextStyle(color: sel ? C.accent : C.muted, fontSize: 13),
        );
      }).toList(),
    );
  }
}

// ── Collapsible section ───────────────────────────────────────────────────────

class _CollapsibleSection extends StatelessWidget {
  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _CollapsibleSection({
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: C.border),
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: C.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (!expanded && summary.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          summary,
                          style: const TextStyle(color: C.muted, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: C.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          child,
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

// ── Strain field with inline autocomplete ─────────────────────────────────────

class _StrainField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _StrainField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Consumer<StrainsProvider>(
      builder: (context, provider, _) {
        final query = controller.text.trim().toLowerCase();
        final suggestions = query.isNotEmpty
            ? provider.strains
                .where((s) => s.name.toLowerCase().contains(query))
                .take(5)
                .toList()
            : <Strain>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'e.g. Wedding Cake',
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          controller.clear();
                          onChanged();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => onChanged(),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border),
                ),
                child: Column(
                  children: suggestions.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    final isExact = s.name.toLowerCase() == query;
                    return Column(
                      children: [
                        if (i > 0) const Divider(height: 1, color: C.border),
                        InkWell(
                          onTap: () {
                            controller.text = s.name;
                            controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: controller.text.length),
                            );
                            onChanged();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: TextStyle(
                                          color: C.text,
                                          fontWeight: isExact ? FontWeight.w600 : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (s.brand != null && s.brand!.isNotEmpty)
                                        Text(s.brand!,
                                            style: const TextStyle(color: C.muted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (isExact)
                                  const Icon(Icons.check, size: 16, color: C.accent)
                                else
                                  const Icon(Icons.north_west, size: 14, color: C.light),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
            if (query.isNotEmpty && suggestions.every((s) => s.name.toLowerCase() != query)) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Will create new strain: "${controller.text.trim()}"',
                  style: const TextStyle(color: C.muted, fontSize: 12),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Picker row ────────────────────────────────────────────────────────────────

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

// ── Effect slider row ─────────────────────────────────────────────────────────

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
            child: Text(label,
                style: TextStyle(color: isSet ? C.text : C.muted, fontSize: 14)),
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
                ? Text(value!.round().toString(),
                    style: const TextStyle(
                        color: C.accent, fontWeight: FontWeight.w600, fontSize: 14))
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

// ── Generic picker bottom sheet ───────────────────────────────────────────────

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
                Text(title,
                    style: const TextStyle(
                        color: C.text, fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
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
                  title: Text(labelOf(item),
                      style: TextStyle(
                          color: C.text,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.normal)),
                  subtitle: subtitleOf != null && subtitleOf!(item) != null
                      ? Text(subtitleOf!(item)!,
                          style: const TextStyle(color: C.muted, fontSize: 13))
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
