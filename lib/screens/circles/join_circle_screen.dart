import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/circles_provider.dart';
import '../../theme/colors.dart';

class JoinCircleScreen extends StatefulWidget {
  final String circleId;
  final String token;
  const JoinCircleScreen({super.key, required this.circleId, required this.token});

  @override
  State<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends State<JoinCircleScreen> {
  Map<String, dynamic>? _circle;
  JoinResult? _result;
  bool _loading = true;
  bool _requesting = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final provider = context.read<CirclesProvider>();
    await provider.init();
    _nameCtrl.text = provider.profile?.displayName ?? '';
    try {
      final circle = await provider.getCircleByToken(widget.token);
      setState(() { _circle = circle; _loading = false; });
    } catch (_) {
      setState(() { _circle = null; _loading = false; });
    }
  }

  Future<void> _request() async {
    final displayName = _nameCtrl.text.trim();
    if (displayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }
    setState(() => _requesting = true);
    final provider = context.read<CirclesProvider>();
    final result = await provider.requestToJoin(widget.circleId, widget.token, displayName);
    if (result == JoinResult.requested && _circle != null) {
      await provider.saveJoinedCircle(_circle!, displayName);
    }
    setState(() {
      _result = result;
      _requesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: C.bg, body: Center(child: CircularProgressIndicator(color: C.circles)));
    }

    if (_circle == null) {
      return Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(backgroundColor: C.bg, leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/circles'))),
        body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.link_off, size: 64, color: C.light),
          SizedBox(height: 16),
          Text('Invalid invite link', style: TextStyle(color: C.text, fontSize: 18, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Text('This link has expired or is invalid.', style: TextStyle(color: C.muted)),
        ])),
      );
    }

    final name = _circle!['name'] as String? ?? '';
    final emoji = _circle!['emoji'] as String? ?? '🌿';

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(backgroundColor: C.bg, leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.go('/circles'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Join "$name"?', style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 24), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('The circle owner will approve your request.', style: TextStyle(color: C.muted, fontSize: 15), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            if (_result == null) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Your name', style: TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: 'How you\'ll appear to members',
                  hintStyle: const TextStyle(color: C.muted),
                  filled: true,
                  fillColor: C.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.circles)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.circles, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _requesting ? null : _request,
                  child: _requesting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: C.white, strokeWidth: 2))
                      : const Text('Request to Join', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else ...[
              _ResultBadge(result: _result!),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.accent),
                onPressed: () => context.go('/circles'),
                child: const Text('Back to Circles'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final JoinResult result;
  const _ResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final (icon, msg, color) = switch (result) {
      JoinResult.requested => (Icons.check_circle, 'You\'re in! Share the circle with others using the invite link.', C.circles),
      JoinResult.alreadyMember => (Icons.group, 'You\'re already a member.', C.sage),
      JoinResult.pending => (Icons.hourglass_empty, 'You already have a pending request.', C.amber),
      JoinResult.invalidToken => (Icons.error_outline, 'Invalid invite token.', C.danger),
      JoinResult.needsProfile => (Icons.person_outline, 'Set up your Circles profile first.', C.muted),
      JoinResult.networkError => (Icons.wifi_off, 'Network error. Check your connection and try again.', C.muted),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(80))),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(msg, style: TextStyle(color: color, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
