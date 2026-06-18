import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../db/database.dart';
import '../../db/models/dispensary.dart';
import '../../db/models/dispensary_profile.dart';
import '../../providers/dispensaries_provider.dart';
import '../../providers/dispensary_profiles_provider.dart';
import '../../theme/colors.dart';

// ─── StashPass operator location ──────────────────────────────────────────────

class _OperatorLocation {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? state;
  final String? zip;
  final String? phone;
  final bool isPrimary;
  final bool active;

  const _OperatorLocation({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.state,
    this.zip,
    this.phone,
    required this.isPrimary,
    required this.active,
  });

  factory _OperatorLocation.fromMap(Map<String, dynamic> m) => _OperatorLocation(
    id: m['id'] as String,
    name: m['name'] as String,
    address: m['address'] as String?,
    city: m['city'] as String?,
    state: m['state'] as String?,
    zip: m['zip'] as String?,
    phone: m['phone'] as String?,
    isPrimary: m['is_primary'] as bool? ?? false,
    active: m['active'] as bool? ?? true,
  );

  String get cityState => [city, state].where((v) => v != null && v.isNotEmpty).join(', ');
  String get mapsQuery => [address, city, state, zip].where((v) => v != null && v.isNotEmpty).join(', ');
}

// ─── Lookup tables ────────────────────────────────────────────────────────────

const _venueLabels = {
  'dispensary': 'Dispensary',
  'wellness_retail': 'Wellness Retail',
  'smoke_shop': 'Smoke Shop',
  'liquor_store': 'Liquor Store',
  'general_retail': 'General Retail',
};

const _tierLabels = {
  'budget': 'Budget \$',
  'mid': 'Mid \$\$',
  'premium': 'Premium \$\$\$',
};

const _dayOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

const _dayLabels = {
  'monday': 'Monday',
  'tuesday': 'Tuesday',
  'wednesday': 'Wednesday',
  'thursday': 'Thursday',
  'friday': 'Friday',
  'saturday': 'Saturday',
  'sunday': 'Sunday',
};

final _todayKey = _dayOrder[DateTime.now().weekday - 1];

Color _parseHex(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
  } catch (_) {
    return fallback;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class DispensaryDetailScreen extends StatefulWidget {
  final String dispensaryId;
  const DispensaryDetailScreen({super.key, required this.dispensaryId});

  @override
  State<DispensaryDetailScreen> createState() => _DispensaryDetailScreenState();
}

class _DispensaryDetailScreenState extends State<DispensaryDetailScreen> {
  Dispensary? _dispensary;
  DispensaryProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppDatabase.getDispensary(widget.dispensaryId);
    final p = await context.read<DispensaryProfilesProvider>().load(widget.dispensaryId);
    if (mounted) setState(() { _dispensary = d; _profile = p; _loading = false; });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bg,
        title: const Text('Delete dispensary?', style: TextStyle(color: C.text)),
        content: const Text(
          'This will permanently remove the dispensary. Sessions linked to it will keep their other data.',
          style: TextStyle(color: C.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<DispensariesProvider>().delete(_dispensary!.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: C.bg,
        body: Center(child: CircularProgressIndicator(color: C.accent)),
      );
    }

    final d = _dispensary;
    if (d == null) {
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(backgroundColor: C.bg, leading: const BackButton()),
        body: const Center(child: Text('Dispensary not found', style: TextStyle(color: C.muted))),
      );
    }

    final p = _profile;

    if (p != null) {
      return _RichProfileScreen(
        dispensary: d,
        profile: p,
        onReload: _load,
        onDelete: _delete,
      );
    }

    // ── No profile — card layout ──────────────────────────────────────────────
    final venueLabel = _venueLabels[d.venueType] ?? d.venueType ?? 'Retail';
    final tierLabel = _tierLabels[d.priceTier] ?? d.priceTier;

    return Scaffold(
      backgroundColor: C.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: C.bg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: C.text),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: C.text),
                onPressed: () => context.push('/discover/dispensary/${d.id}/edit').then((_) => _load()),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: C.text),
                onPressed: () => context.push(Uri(path: '/share', queryParameters: {
                  'type': 'dispensary', 'name': d.name, 'sub': venueLabel, 'dispensaryId': d.id,
                }).toString()),
              ),
            ],
            title: Text(d.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: C.accentLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: C.accent.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: C.accent.withAlpha(40),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.storefront, color: C.accent, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 20)),
                              const SizedBox(height: 6),
                              Row(children: [
                                _TypeChip(venueLabel),
                                if (tierLabel != null) ...[const SizedBox(width: 6), _TypeChip(tierLabel)],
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StashPassStatusRow(isMatched: d.stashpassOperatorId != null),
                  const SizedBox(height: 16),
                  if (d.staffRating != null || d.vibeRating != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                      child: Column(children: [
                        if (d.staffRating != null) _RatingRow(label: 'Staff Knowledge', rating: d.staffRating!),
                        if (d.staffRating != null && d.vibeRating != null) const SizedBox(height: 10),
                        if (d.vibeRating != null) _RatingRow(label: 'Vibe', rating: d.vibeRating!),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (d.notes != null && d.notes!.isNotEmpty) ...[
                    const Text('Notes', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                      child: Text(d.notes!, style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
                    ),
                    const SizedBox(height: 20),
                  ],
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add profile info'),
                    onPressed: () => context.push('/discover/dispensary/${d.id}/profile/edit').then((_) => _load()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.accent,
                      side: const BorderSide(color: C.accent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.group_outlined),
                      label: const Text('Share to Circle'),
                      onPressed: () => context.push(Uri(path: '/share', queryParameters: {
                        'type': 'dispensary', 'name': d.name, 'sub': venueLabel, 'dispensaryId': d.id,
                      }).toString()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.circles,
                        side: const BorderSide(color: C.circles),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.danger,
                        side: const BorderSide(color: C.danger),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Delete Dispensary', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Rich brand-page screen (profile exists) ──────────────────────────────────

class _RichProfileScreen extends StatefulWidget {
  final Dispensary dispensary;
  final DispensaryProfile profile;
  final VoidCallback onReload;
  final Future<void> Function() onDelete;

  const _RichProfileScreen({
    required this.dispensary,
    required this.profile,
    required this.onReload,
    required this.onDelete,
  });

  @override
  State<_RichProfileScreen> createState() => _RichProfileScreenState();
}

class _RichProfileScreenState extends State<_RichProfileScreen> {
  List<_OperatorLocation> _locations = [];
  bool _locationsLoading = false;
  bool _isEditor = false;
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _checkEditor();
    _fetchOperatorProfile();
  }

  @override
  void didUpdateWidget(_RichProfileScreen old) {
    super.didUpdateWidget(old);
    if (old.dispensary.stashpassOperatorId != widget.dispensary.stashpassOperatorId) {
      _fetchLocations();
    }
  }

  Future<void> _checkEditor() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isEditor = prefs.getBool('is_editor') ?? false);
  }

  Future<void> _fetchLocations() async {
    final opId = widget.dispensary.stashpassOperatorId;
    if (opId == null || opId.isEmpty) return;
    if (mounted) setState(() => _locationsLoading = true);
    try {
      final res = await http.get(Uri.parse('$kCirclesApiBase/operators/$opId/locations'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawList = data['locations'] as List? ?? [];
        final locs = rawList.cast<Map<String, dynamic>>().map(_OperatorLocation.fromMap).toList();
        if (mounted) setState(() {
          _locations = locs;
          _locationsLoading = false;
        });
      } else {
        if (mounted) setState(() => _locationsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _locationsLoading = false);
    }
  }

  Future<void> _fetchOperatorProfile() async {
    final opId = widget.dispensary.stashpassOperatorId;
    if (opId == null || opId.isEmpty) return;
    try {
      final res = await http.get(Uri.parse('$kCirclesApiBase/operators/$opId/profile'));
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final profile = data['profile'] as Map<String, dynamic>?;
        final logoUrl = profile?['logo_url'] as String?;
        if (_isValidUrl(logoUrl) && mounted) {
          setState(() => _logoUrl = logoUrl);
        }
      }
    } catch (_) {
      // Logo is optional — ignore network errors
    }
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showAddLocationSheet() async {
    final opId = widget.dispensary.stashpassOperatorId;
    if (opId == null || opId.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddLocationSheet(
        operatorId: opId,
        onSaved: _fetchLocations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dispensary;
    final p = widget.profile;
    final heroTop = _parseHex(p.backgroundColor, const Color(0xFF5C3A1C));
    final heroBot = _parseHex(p.primaryColor, C.accent);
    final accentColor = _parseHex(p.primaryColor, C.accent);
    final venueLabel = _venueLabels[d.venueType] ?? d.venueType ?? 'Retail';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: C.bg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              pinned: true,
              centerTitle: false,
              expandedHeight: 160,
              forceElevated: innerBoxIsScrolled,
              backgroundColor: heroBot,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: C.white),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: C.white),
                  tooltip: 'Edit dispensary',
                  onPressed: () => context.push('/discover/dispensary/${d.id}/edit').then((_) => widget.onReload()),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: C.white),
                  tooltip: 'Share to Circle',
                  onPressed: () => context.push(Uri(path: '/share', queryParameters: {
                    'type': 'dispensary', 'name': d.name, 'sub': venueLabel, 'dispensaryId': d.id,
                  }).toString()),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                expandedTitleScale: 1.0,
                titlePadding: EdgeInsetsDirectional.only(
                  start: (widget.dispensary.stashpassOperatorId?.isNotEmpty ?? false) ? 32.0 : 16.0,
                  bottom: 54.0,
                ),
                title: Text(
                  d.name,
                  style: const TextStyle(color: C.white, fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                background: _HeroBg(
                  topColor: heroTop,
                  botColor: heroBot,
                  logoUrl: _logoUrl,
                ),
              ),
              bottom: TabBar(
                labelColor: C.white,
                unselectedLabelColor: Colors.white.withAlpha(160),
                indicatorColor: C.white,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
                tabs: const [
                  Tab(text: 'About'),
                  Tab(text: 'Locations'),
                  Tab(text: 'Hours'),
                  Tab(text: 'Payment'),
                ],
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _AboutTab(
                dispensary: d,
                profile: p,
                accentColor: accentColor,
                onReload: widget.onReload,
                onDelete: widget.onDelete,
              ),
              _LocationsTab(
                dispensary: d,
                locations: _locations,
                loading: _locationsLoading,
                accentColor: accentColor,
                isEditor: _isEditor,
                onAddLocation: _showAddLocationSheet,
              ),
              _HoursTab(profile: p, accentColor: accentColor),
              _PaymentTab(profile: p),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── About tab ────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  final Dispensary dispensary;
  final DispensaryProfile profile;
  final Color accentColor;
  final VoidCallback onReload;
  final Future<void> Function() onDelete;

  const _AboutTab({
    required this.dispensary,
    required this.profile,
    required this.accentColor,
    required this.onReload,
    required this.onDelete,
  });

  String? get _orderingUrl {
    if (profile.dutchieUrl?.isNotEmpty ?? false) return profile.dutchieUrl;
    if (profile.leaflyUrl?.isNotEmpty ?? false) return profile.leaflyUrl;
    if (profile.otherOrderingUrl?.isNotEmpty ?? false) return profile.otherOrderingUrl;
    return null;
  }

  String get _orderingLabel {
    if (profile.dutchieUrl?.isNotEmpty ?? false) return 'Order on Dutchie';
    if (profile.leaflyUrl?.isNotEmpty ?? false) return 'Order on Leafly';
    if (profile.orderingPlatform?.isNotEmpty ?? false) return 'Order on ${profile.orderingPlatform}';
    return 'Order Online';
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $text'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = dispensary;
    final p = profile;
    final specials = p.currentSpecials;
    final orderingUrl = _orderingUrl;
    final hasPersonalInfo = (d.notes?.isNotEmpty ?? false) || d.staffRating != null || d.vibeRating != null;
    final venueLabel = _venueLabels[dispensary.venueType] ?? dispensary.venueType ?? 'Retail';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        _StashPassStatusRow(isMatched: dispensary.stashpassOperatorId != null),
        const SizedBox(height: 20),
        // About
        if (p.about != null && p.about!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accentColor, width: 3)),
            ),
            child: Text(p.about!, style: const TextStyle(color: C.text, fontSize: 15, height: 1.65)),
          ),
          const SizedBox(height: 28),
        ],

        // Ordering CTA
        if (orderingUrl != null) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _copyToClipboard(context, orderingUrl),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: C.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.open_in_new_outlined, size: 17),
                  const SizedBox(width: 8),
                  Text('$_orderingLabel  →'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],

        // Specials
        if (specials.isNotEmpty) ...[
          Row(children: const [
            Icon(Icons.local_offer_outlined, size: 15, color: C.amber),
            SizedBox(width: 6),
            Text("This Week's Specials",
                style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          ...specials.map((s) => _SpecialCard(
            item: s['item'] as String? ?? '',
            description: s['description'] as String? ?? '',
          )),
          const SizedBox(height: 28),
        ],

        // Links
        if (p.hasLinks) ...[
          const _SectionLabel('FIND US ONLINE'),
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: C.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.border),
            ),
            child: Column(children: [
              if (p.website?.isNotEmpty ?? false)
                _LinkTile(icon: Icons.language_outlined, label: 'Website', url: p.website!,
                    onTap: () => _copyToClipboard(context, p.website!)),
              if (p.instagram?.isNotEmpty ?? false)
                _LinkTile(icon: Icons.camera_alt_outlined, label: 'Instagram', url: p.instagram!,
                    onTap: () => _copyToClipboard(context, p.instagram!)),
              if (p.leaflyUrl?.isNotEmpty ?? false)
                _LinkTile(icon: Icons.local_florist_outlined, label: 'Leafly', url: p.leaflyUrl!,
                    onTap: () => _copyToClipboard(context, p.leaflyUrl!)),
              if (p.dutchieUrl?.isNotEmpty ?? false)
                _LinkTile(icon: Icons.shopping_bag_outlined, label: 'Dutchie', url: p.dutchieUrl!,
                    onTap: () => _copyToClipboard(context, p.dutchieUrl!)),
              if (p.otherOrderingUrl?.isNotEmpty ?? false)
                _LinkTile(icon: Icons.open_in_new_outlined,
                    label: p.orderingPlatform ?? 'Order Online',
                    url: p.otherOrderingUrl!,
                    onTap: () => _copyToClipboard(context, p.otherOrderingUrl!),
                    isLast: true),
            ]),
          ),
          const SizedBox(height: 28),
        ],

        // Personal notes / ratings
        if (hasPersonalInfo) ...[
          Row(children: [
            const Expanded(child: Divider(color: C.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('YOUR NOTES',
                  style: TextStyle(color: C.light, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            ),
            const Expanded(child: Divider(color: C.border)),
          ]),
          const SizedBox(height: 16),
          if (d.staffRating != null || d.vibeRating != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
              child: Column(children: [
                if (d.staffRating != null) _RatingRow(label: 'Staff Knowledge', rating: d.staffRating!),
                if (d.staffRating != null && d.vibeRating != null) const SizedBox(height: 10),
                if (d.vibeRating != null) _RatingRow(label: 'Vibe', rating: d.vibeRating!),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          if (d.notes != null && d.notes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: C.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
              child: Text(d.notes!, style: const TextStyle(color: C.muted, fontSize: 14, height: 1.5)),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
        ],

        // Edit profile
        TextButton.icon(
          onPressed: () => context.push('/discover/dispensary/${d.id}/profile/edit').then((_) => onReload()),
          icon: const Icon(Icons.edit_outlined, size: 15),
          label: const Text('Edit Profile'),
          style: TextButton.styleFrom(
            foregroundColor: C.muted,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 16),

        // Share
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.group_outlined),
            label: const Text('Share to Circle'),
            onPressed: () => context.push(Uri(path: '/share', queryParameters: {
              'type': 'dispensary', 'name': d.name, 'sub': venueLabel, 'dispensaryId': d.id,
            }).toString()),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.circles,
              side: const BorderSide(color: C.circles),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Delete
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: C.danger,
              side: const BorderSide(color: C.danger),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Delete Dispensary', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ─── Locations tab ────────────────────────────────────────────────────────────

class _LocationsTab extends StatelessWidget {
  final Dispensary dispensary;
  final List<_OperatorLocation> locations;
  final bool loading;
  final Color accentColor;
  final bool isEditor;
  final VoidCallback onAddLocation;

  const _LocationsTab({
    required this.dispensary,
    required this.locations,
    required this.loading,
    required this.accentColor,
    required this.isEditor,
    required this.onAddLocation,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: C.accent));
    }

    final hasOpId = dispensary.stashpassOperatorId != null && dispensary.stashpassOperatorId!.isNotEmpty;

    if (!hasOpId) {
      return _EmptyTabState(
        icon: Icons.location_off_outlined,
        message: 'Not connected to a StashPass operator',
        sub: 'Link a StashPass operator ID to see locations here',
      );
    }

    // Primary first, then alphabetical
    final sorted = [...locations]..sort((a, b) {
      if (a.isPrimary && !b.isPrimary) return -1;
      if (!a.isPrimary && b.isPrimary) return 1;
      return a.name.compareTo(b.name);
    });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        if (isEditor) ...[
          OutlinedButton.icon(
            onPressed: onAddLocation,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Add Location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.accent,
              side: const BorderSide(color: C.accent),
              padding: const EdgeInsets.symmetric(vertical: 11),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (sorted.isEmpty)
          _EmptyTabState(
            icon: Icons.storefront_outlined,
            message: 'No locations on file',
            sub: isEditor ? 'Tap "Add Location" above to add the first one' : 'Operator locations appear here once added',
          )
        else
          ...sorted.asMap().entries.map((e) => Padding(
            padding: EdgeInsets.only(bottom: e.key < sorted.length - 1 ? 12 : 0),
            child: _LocationCard(loc: e.value, accentColor: accentColor),
          )),
      ],
    );
  }
}

// ─── Add location bottom sheet ────────────────────────────────────────────────

class _AddLocationSheet extends StatefulWidget {
  final String operatorId;
  final VoidCallback onSaved;

  const _AddLocationSheet({required this.operatorId, required this.onSaved});

  @override
  State<_AddLocationSheet> createState() => _AddLocationSheetState();
}

class _AddLocationSheetState extends State<_AddLocationSheet> {
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  bool _isPrimary = false;
  bool _active    = true;
  bool _saving    = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose(); _cityCtrl.dispose();
    _stateCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final city = _cityCtrl.text.trim();
    if (city.isEmpty) { setState(() => _error = 'City is required'); return; }
    setState(() { _saving = true; _error = null; });

    final body = <String, dynamic>{
      'city': city,
      'active': _active,
      'is_primary': _isPrimary,
    };
    final name = _nameCtrl.text.trim();
    if (name.isNotEmpty) body['name'] = name;
    final address = _addressCtrl.text.trim();
    if (address.isNotEmpty) body['address'] = address;
    final state = _stateCtrl.text.trim();
    if (state.isNotEmpty) body['state'] = state;
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty) body['phone'] = phone;

    // name is required by the API — use city as fallback if not provided
    if (!body.containsKey('name')) body['name'] = city;

    try {
      final res = await http.post(
        Uri.parse('$kCirclesApiBase/operators/${widget.operatorId}/locations'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-secret': kCirclesApiSecret,
        },
        body: jsonEncode(body),
      );
      if (res.statusCode == 201) {
        widget.onSaved();
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) setState(() { _saving = false; _error = 'Save failed (${res.statusCode})'; });
      }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Network error — check connection'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Text('Add Location', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 17)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close, color: C.muted), onPressed: () => Navigator.pop(context)),
            ]),
            const Divider(color: C.border),
            const SizedBox(height: 8),

            _field('Location name (optional)', _nameCtrl, hint: 'e.g. Hoboken, Flagship'),
            const SizedBox(height: 14),
            _field('Address', _addressCtrl, hint: '123 Main St'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(flex: 3, child: _field('City *', _cityCtrl, hint: 'Hoboken')),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _field('State', _stateCtrl, hint: 'NJ')),
            ]),
            const SizedBox(height: 14),
            _field('Phone (optional)', _phoneCtrl, hint: '(201) 555-0100', keyboardType: TextInputType.phone),
            const SizedBox(height: 20),

            // Toggles
            Container(
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.border),
              ),
              child: Column(children: [
                SwitchListTile(
                  title: const Text('Primary location', style: TextStyle(color: C.text, fontSize: 14)),
                  subtitle: const Text('Shown first and used for city display', style: TextStyle(color: C.muted, fontSize: 12)),
                  value: _isPrimary,
                  activeColor: C.accent,
                  onChanged: (v) => setState(() => _isPrimary = v),
                  dense: true,
                ),
                const Divider(height: 1, color: C.border, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Active', style: TextStyle(color: C.text, fontSize: 14)),
                  value: _active,
                  activeColor: C.accent,
                  onChanged: (v) => setState(() => _active = v),
                  dense: true,
                ),
              ]),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: C.danger, fontSize: 13)),
            ],

            const SizedBox(height: 20),
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
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Add Location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {
    String? hint, TextInputType? keyboardType,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: C.text, fontWeight: FontWeight.w500, fontSize: 13)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: C.light),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ],
  );
}

// ─── Location card ────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final _OperatorLocation loc;
  final Color accentColor;

  const _LocationCard({required this.loc, required this.accentColor});

  Future<void> _openMaps(BuildContext context) async {
    final query = loc.mapsQuery;
    if (query.isEmpty) return;
    final uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    // Fallback: copy to clipboard
    await Clipboard.setData(ClipboardData(text: query));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied — paste in Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = loc.active;
    final textColor = isActive ? C.text : C.muted;
    final subColor = isActive ? C.muted : C.light;

    return Material(
      color: C.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loc.mapsQuery.isNotEmpty ? () => _openMaps(context) : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: loc.isPrimary ? accentColor.withAlpha(120) : C.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pin icon
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: loc.isPrimary ? accentColor.withAlpha(30) : C.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: loc.isPrimary ? accentColor.withAlpha(80) : C.border,
                  ),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: loc.isPrimary ? accentColor : C.muted,
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.name,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (loc.isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: accentColor.withAlpha(100)),
                            ),
                            child: Text(
                              'Primary',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (!isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: C.surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: C.border),
                            ),
                            child: const Text(
                              'Closed',
                              style: TextStyle(color: C.light, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (loc.address != null && loc.address!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(loc.address!, style: TextStyle(color: subColor, fontSize: 13)),
                    ],
                    if (loc.cityState.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [loc.cityState, if (loc.zip != null && loc.zip!.isNotEmpty) loc.zip!].join(' '),
                        style: TextStyle(color: subColor, fontSize: 13),
                      ),
                    ],
                    if (loc.phone != null && loc.phone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.phone_outlined, size: 12, color: C.light),
                        const SizedBox(width: 4),
                        Text(loc.phone!, style: TextStyle(color: subColor, fontSize: 12)),
                      ]),
                    ],
                  ],
                ),
              ),

              // Maps arrow
              if (loc.mapsQuery.isNotEmpty) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.map_outlined, size: 18, color: isActive ? accentColor : C.light),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hours tab ────────────────────────────────────────────────────────────────

class _HoursTab extends StatelessWidget {
  final DispensaryProfile profile;
  final Color accentColor;

  const _HoursTab({required this.profile, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final hours = profile.hoursMap;
    final daysWithHours = _dayOrder.where((day) => hours.containsKey(day)).toList();

    if (daysWithHours.isEmpty) {
      return const _EmptyTabState(
        icon: Icons.schedule_outlined,
        message: 'No hours on file',
        sub: 'Edit the profile to add store hours',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.border),
          ),
          child: Column(
            children: daysWithHours.asMap().entries.map((e) => _HourRow(
              day: e.value,
              time: hours[e.value]!,
              isToday: e.value == _todayKey,
              isLast: e.key == daysWithHours.length - 1,
              accentColor: accentColor,
            )).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Payment tab ──────────────────────────────────────────────────────────────

class _PaymentTab extends StatelessWidget {
  final DispensaryProfile profile;

  const _PaymentTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final payments = profile.paymentList;

    if (payments.isEmpty) {
      return const _EmptyTabState(
        icon: Icons.payments_outlined,
        message: 'No payment methods on file',
        sub: 'Edit the profile to add accepted payment methods',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        const _SectionLabel('ACCEPTED PAYMENT'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: payments.map((m) => _PaymentChip(m)).toList(),
        ),
      ],
    );
  }
}

// ─── Shared empty state ───────────────────────────────────────────────────────

class _EmptyTabState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyTabState({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: C.border),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: C.muted, fontWeight: FontWeight.w600, fontSize: 15),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(color: C.light, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

// ─── Hero background ──────────────────────────────────────────────────────────

class _HeroBg extends StatelessWidget {
  final Color topColor;
  final Color botColor;
  final String? logoUrl;

  const _HeroBg({required this.topColor, required this.botColor, this.logoUrl});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topColor, botColor],
          ),
        ),
      ),
      if (logoUrl != null && logoUrl!.isNotEmpty)
        Positioned(
          top: kToolbarHeight + 16.0,
          left: 32.0,
          child: _LogoCircle(url: logoUrl!),
        ),
    ],
  );
}

class _LogoCircle extends StatefulWidget {
  final String url;
  const _LogoCircle({required this.url});

  @override
  State<_LogoCircle> createState() => _LogoCircleState();
}

class _LogoCircleState extends State<_LogoCircle> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(46),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(89), width: 1.5),
      ),
      child: ClipOval(
        child: Image.network(
          widget.url,
          width: 56,
          height: 56,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _failed = true);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: C.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.9,
    ),
  );
}

// ─── Payment chip ─────────────────────────────────────────────────────────────

class _PaymentChip extends StatelessWidget {
  final String method;
  const _PaymentChip(this.method);

  static IconData _icon(String m) => switch (m.toLowerCase()) {
    'cash'   => Icons.payments_outlined,
    'debit'  => Icons.credit_card_outlined,
    'credit' => Icons.credit_card,
    'dutchie' => Icons.shopping_bag_outlined,
    'leafly' => Icons.local_florist_outlined,
    'canpay' => Icons.account_balance_wallet_outlined,
    _        => Icons.attach_money,
  };

  @override
  Widget build(BuildContext context) {
    final label = method.isEmpty ? method : method[0].toUpperCase() + method.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(method), size: 14, color: C.accent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: C.text, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Hour row ─────────────────────────────────────────────────────────────────

class _HourRow extends StatelessWidget {
  final String day;
  final String time;
  final bool isToday;
  final bool isLast;
  final Color accentColor;

  const _HourRow({
    required this.day,
    required this.time,
    required this.isToday,
    required this.isLast,
    this.accentColor = C.accent,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: isToday ? accentColor.withAlpha(28) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 95,
              child: Text(
                _dayLabels[day] ?? day,
                style: TextStyle(
                  color: isToday ? accentColor : C.muted,
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
            Expanded(
              child: Text(
                time,
                style: TextStyle(
                  color: isToday ? accentColor : C.text,
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ),
            if (isToday)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(color: C.white, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 1, color: C.border, indent: 14, endIndent: 14),
    ],
  );
}

// ─── Special card ─────────────────────────────────────────────────────────────

class _SpecialCard extends StatelessWidget {
  final String item;
  final String description;
  const _SpecialCard({required this.item, required this.description});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: C.amberLt, borderRadius: BorderRadius.circular(6)),
          child: const Icon(Icons.local_offer_outlined, size: 14, color: C.amber),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 13)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(color: C.muted, fontSize: 12, height: 1.4)),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Link tile ────────────────────────────────────────────────────────────────

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String url;
  final VoidCallback onTap;
  final bool isLast;

  const _LinkTile({
    required this.icon,
    required this.label,
    required this.url,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: C.circlesLt,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: C.circles),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(color: C.text, fontWeight: FontWeight.w500, fontSize: 13)),
                    Text(url, style: const TextStyle(color: C.muted, fontSize: 11), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.copy_outlined, size: 13, color: C.light),
            ],
          ),
        ),
      ),
      if (!isLast) const Divider(height: 1, color: C.border, indent: 14, endIndent: 14),
    ],
  );
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

// StashPass origin / enrichment status row
// State 1 (isMatched=false): muted — dispensary not in StashPass network
// State 2 (isMatched=true):  purple — matched; no hasContent equivalent exists for
//   dispensary profiles, so state 3 is not distinguishable here
class _StashPassStatusRow extends StatelessWidget {
  final bool isMatched;
  const _StashPassStatusRow({required this.isMatched});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isMatched ? Icons.auto_awesome_outlined : Icons.radio_button_unchecked,
            size: 14,
            color: isMatched ? C.purple : C.muted,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              isMatched
                  ? 'On the radar — we\'re building out the full profile'
                  : 'Not yet in the StashPass network',
              style: TextStyle(
                color: isMatched ? C.purple : C.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
}

class _RatingRow extends StatelessWidget {
  final String label;
  final int rating;
  const _RatingRow({required this.label, required this.rating});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(color: C.muted, fontSize: 13))),
      ...List.generate(5, (i) => Icon(i < rating ? Icons.star : Icons.star_border, size: 18, color: C.gold)),
      const SizedBox(width: 6),
      Text('$rating / 5', style: const TextStyle(color: C.muted, fontSize: 12)),
    ],
  );
}

class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: C.accent.withAlpha(20),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: C.accent.withAlpha(60)),
    ),
    child: Text(label, style: const TextStyle(color: C.accent, fontSize: 12, fontWeight: FontWeight.w500)),
  );
}
