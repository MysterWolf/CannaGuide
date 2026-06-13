import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/circles_provider.dart';
import '../../theme/colors.dart';

class CircleDetailScreen extends StatefulWidget {
  final String circleId;
  const CircleDetailScreen({super.key, required this.circleId});

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  Map<String, dynamic>? _circle;
  List<Map<String, dynamic>> _shares = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<CirclesProvider>();
    _myUserId = provider.profile?.userId;
    final circle = await provider.getCircle(widget.circleId);
    final shares = await provider.getShares(widget.circleId);
    final pending = await provider.getPendingRequests(widget.circleId);
    if (mounted) {
      setState(() {
        _circle = circle;
        _shares = shares;
        _pendingRequests = pending;
        _loading = false;
      });
    }
  }

  bool get _isOwner => _circle?['owner_id'] == _myUserId;

  void _showInviteModal() async {
    final link = await context.read<CirclesProvider>().getInviteLink(widget.circleId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Invite to Circle', style: TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 20),
            QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: C.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.accent),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: C.text),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy link'),
                    style: OutlinedButton.styleFrom(foregroundColor: C.circles, side: const BorderSide(color: C.circles)),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 2)));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                    style: FilledButton.styleFrom(backgroundColor: C.circles),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPendingModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: C.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending Requests (${_pendingRequests.length})', style: const TextStyle(color: C.text, fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 16),
              if (_pendingRequests.isEmpty)
                const Text('No pending requests', style: TextStyle(color: C.muted)),
              ..._pendingRequests.map((req) {
                final name = req['display_name'] as String? ?? 'Unknown';
                final userId = req['user_id'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: C.circlesLt, shape: BoxShape.circle),
                        child: const Center(child: Text('👤', style: TextStyle(fontSize: 18))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w500))),
                      TextButton(
                        onPressed: () async {
                          await context.read<CirclesProvider>().approveRequest(widget.circleId, userId, name);
                          await _load();
                          setModal(() {});
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Approve', style: TextStyle(color: C.circles)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: C.danger),
                        onPressed: () async {
                          await context.read<CirclesProvider>().declineRequest(widget.circleId, userId);
                          await _load();
                          setModal(() {});
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: C.bg, body: Center(child: CircularProgressIndicator(color: C.circles)));

    final name = _circle?['name'] as String? ?? '';
    final emoji = _circle?['emoji'] as String? ?? '🌿';

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        title: Row(children: [
          Text(emoji),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back), color: C.text, onPressed: () => context.pop()),
        actions: [
          if (_isOwner && _pendingRequests.isNotEmpty)
            Stack(
              children: [
                IconButton(icon: const Icon(Icons.group_add_outlined, color: C.circles), onPressed: _showPendingModal),
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: C.danger, shape: BoxShape.circle),
                    child: Text('${_pendingRequests.length}', style: const TextStyle(color: C.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          IconButton(icon: const Icon(Icons.person_add_outlined, color: C.circles), onPressed: _showInviteModal),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.circles,
        icon: const Icon(Icons.share, color: C.white),
        label: const Text('Share', style: TextStyle(color: C.white)),
        onPressed: () => context.push('/circles/${widget.circleId}/share'),
      ),
      body: _shares.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.forum_outlined, size: 64, color: C.light),
                const SizedBox(height: 16),
                const Text('No shares yet', style: TextStyle(color: C.muted, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Tap Share to post the first one', style: TextStyle(color: C.light, fontSize: 14)),
              ]),
            )
          : RefreshIndicator(
              color: C.circles,
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _shares.length,
                itemBuilder: (context, i) => _ShareCard(
                  share: _shares[i],
                  myUserId: _myUserId ?? '',
                  onReactionToggled: () => _load(),
                ),
              ),
            ),
    );
  }
}

class _ShareCard extends StatefulWidget {
  final Map<String, dynamic> share;
  final String myUserId;
  final VoidCallback onReactionToggled;

  const _ShareCard({required this.share, required this.myUserId, required this.onReactionToggled});

  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard> {
  bool _showComments = false;
  final _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _reactions = [];
  bool _loadedExtra = false;

  Future<void> _loadExtra() async {
    if (_loadedExtra) return;
    final provider = context.read<CirclesProvider>();
    final shareId = widget.share['id'] as String;
    _comments = await provider.getComments(shareId);
    _reactions = await provider.getReactions(shareId);
    _loadedExtra = true;
    if (mounted) setState(() {});
  }

  Future<void> _toggleReaction(String type) async {
    final provider = context.read<CirclesProvider>();
    await provider.toggleReaction(widget.share['id'] as String, type);
    _reactions = await provider.getReactions(widget.share['id'] as String);
    setState(() {});
    widget.onReactionToggled();
  }

  int _countReaction(String type) => _reactions.where((r) => r['type'] == type).length;
  bool _hasReaction(String type) => _reactions.any((r) => r['user_id'] == widget.myUserId && r['type'] == type);

  @override
  Widget build(BuildContext context) {
    final shareId = widget.share['id'] as String;
    final sharerId = widget.share['sharer_id'] as String;
    final type = widget.share['type'] as String? ?? 'product';
    final note = widget.share['note'] as String? ?? '';
    final timestamp = widget.share['timestamp'] as int? ?? 0;
    final payloadStr = widget.share['payload'] as String? ?? '{}';
    Map<String, dynamic> payload = {};
    try { payload = jsonDecode(payloadStr) as Map<String, dynamic>; } catch (_) {}

    final displayName = sharerId == context.read<CirclesProvider>().profile?.userId
        ? context.read<CirclesProvider>().profile?.displayName ?? 'You'
        : sharerId.substring(0, 6);
    final dateStr = DateFormat('MMM d, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(timestamp));

    return FutureBuilder(
      future: _loadedExtra ? null : Future(() async { await _loadExtra(); }),
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: C.circlesLt, shape: BoxShape.circle),
                    child: Center(child: Text(context.read<CirclesProvider>().profile?.avatar ?? '🌿', style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(displayName, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(dateStr, style: const TextStyle(color: C.light, fontSize: 12)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: C.circlesLt, borderRadius: BorderRadius.circular(20)),
                    child: Text(type, style: const TextStyle(color: C.circles, fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
              // Payload mini-card
              if (payload.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (payload['name'] != null) Text(payload['name'] as String, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 14)),
                      if (payload['sub'] != null) Text(payload['sub'] as String, style: const TextStyle(color: C.muted, fontSize: 12)),
                    ]),
                  ),
                ),
              ],
              // Note
              if (note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(note, style: const TextStyle(color: C.text, fontSize: 14)),
                ),
              ],
              const SizedBox(height: 12),
              // Reactions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  _ReactionBtn(emoji: '🔖', label: 'Save', count: _countReaction('save'), active: _hasReaction('save'), onTap: () => _toggleReaction('save')),
                  const SizedBox(width: 8),
                  _ReactionBtn(emoji: '🔥', label: 'Fire', count: _countReaction('fire'), active: _hasReaction('fire'), onTap: () => _toggleReaction('fire')),
                  const SizedBox(width: 8),
                  _ReactionBtn(emoji: '🤔', label: 'Curious', count: _countReaction('curious'), active: _hasReaction('curious'), onTap: () => _toggleReaction('curious')),
                  const Spacer(),
                  GestureDetector(
                    onTap: () { setState(() => _showComments = !_showComments); if (!_loadedExtra) _loadExtra(); },
                    child: Row(children: [
                      Icon(Icons.chat_bubble_outline, size: 16, color: _showComments ? C.circles : C.light),
                      const SizedBox(width: 4),
                      Text('${_comments.length}', style: TextStyle(color: _showComments ? C.circles : C.light, fontSize: 13)),
                    ]),
                  ),
                ]),
              ),
              // Comments
              if (_showComments) ...[
                const Divider(color: C.border, height: 24),
                if (_comments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: _comments.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(width: 28, height: 28, decoration: const BoxDecoration(color: C.circlesLt, shape: BoxShape.circle), child: const Center(child: Text('💬', style: TextStyle(fontSize: 14)))),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['display_name'] as String? ?? 'Member', style: const TextStyle(color: C.text, fontWeight: FontWeight.w600, fontSize: 12)),
                            Text(c['text'] as String? ?? '', style: const TextStyle(color: C.text, fontSize: 13)),
                          ])),
                        ]),
                      )).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a comment…',
                          hintStyle: const TextStyle(color: C.light, fontSize: 13),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true, fillColor: C.bg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: C.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: C.border)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final text = _commentCtrl.text.trim();
                        if (text.isEmpty) return;
                        final circles = context.read<CirclesProvider>();
                        await circles.addComment(shareId, text);
                        _commentCtrl.clear();
                        _comments = await circles.getComments(shareId);
                        setState(() {});
                      },
                      child: Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(color: C.circles, shape: BoxShape.circle),
                        child: const Icon(Icons.send, size: 16, color: C.white),
                      ),
                    ),
                  ]),
                ),
              ] else
                const SizedBox(height: 14),
            ],
          ),
        );
      },
    );
  }
}

class _ReactionBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _ReactionBtn({required this.emoji, required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? C.circlesLt : C.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? C.circles : C.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          if (count > 0) ...[const SizedBox(width: 4), Text('$count', style: TextStyle(color: active ? C.circles : C.muted, fontSize: 12))],
        ]),
      ),
    );
  }
}
