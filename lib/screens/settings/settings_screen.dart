import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/circles_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/colors.dart';

const _avatarOptions = ['🌿', '🍃', '✨', '🌙', '🔥', '💫'];

const _appVersion = '1.0.2+1';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<CirclesProvider>().profile;
      if (profile != null) _nameCtrl.text = profile.displayName;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final circles = context.read<CirclesProvider>();
    final avatar = circles.profile?.avatar ?? _avatarOptions[0];
    await circles.saveProfile(name, avatar);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _setAvatar(String avatar) async {
    final circles = context.read<CirclesProvider>();
    final name = circles.profile?.displayName ?? _nameCtrl.text.trim();
    await circles.saveProfile(name, avatar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              backgroundColor: C.bg,
              floating: true,
              title: Text(
                'Settings',
                style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 22),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionHeader('Profile'),
                  const SizedBox(height: 12),
                  Consumer<CirclesProvider>(
                    builder: (context, circles, _) {
                      final profile = circles.profile;
                      final currentAvatar = profile?.avatar ?? _avatarOptions[0];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Display name', style: TextStyle(color: C.muted, fontSize: 13)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  decoration: _inputDec('Your name'),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _saveName(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: _saving ? null : _saveName,
                                style: FilledButton.styleFrom(backgroundColor: C.accent),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text('Avatar', style: TextStyle(color: C.muted, fontSize: 13)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            children: _avatarOptions.map((a) {
                              final sel = a == currentAvatar;
                              return GestureDetector(
                                onTap: () => _setAvatar(a),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: sel ? C.accentLight : C.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: sel ? C.accent : C.border,
                                      width: sel ? 2 : 1,
                                    ),
                                  ),
                                  child: Center(child: Text(a, style: const TextStyle(fontSize: 26))),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  _SectionHeader('Appearance'),
                  const SizedBox(height: 12),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      return _SettingsCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Theme', style: TextStyle(color: C.text, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                              ],
                              selected: {settings.themeMode},
                              onSelectionChanged: (v) => settings.setThemeMode(v.first),
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) return C.accentLight;
                                  return C.surface;
                                }),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  _SectionHeader('Subscription'),
                  const SizedBox(height: 12),
                  Consumer<SettingsProvider>(
                    builder: (context, settings, _) {
                      final tierLabel = switch (settings.tier) {
                        'pro' => 'Pro',
                        'ai' => 'AI',
                        _ => 'Free',
                      };
                      return _SettingsCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current plan: $tierLabel',
                                    style: const TextStyle(color: C.text, fontWeight: FontWeight.w500),
                                  ),
                                  if (settings.tier == 'free')
                                    const Text(
                                      'Upgrade for AI features and priority support',
                                      style: TextStyle(color: C.muted, fontSize: 13),
                                    ),
                                ],
                              ),
                            ),
                            if (settings.tier == 'free')
                              OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('IAP coming soon')),
                                  );
                                },
                                style: OutlinedButton.styleFrom(foregroundColor: C.accent, side: const BorderSide(color: C.accent)),
                                child: const Text('Upgrade'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  _SectionHeader('About'),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    child: Column(
                      children: [
                        _InfoRow(label: 'Version', value: _appVersion),
                        const Divider(color: C.border, height: 16),
                        _InfoRow(label: 'Package', value: 'com.mysterwolf.cannaguide'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(hintText: hint);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: C.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: child,
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: C.muted, fontSize: 14)),
          Text(value, style: const TextStyle(color: C.text, fontSize: 14)),
        ],
      );
}
