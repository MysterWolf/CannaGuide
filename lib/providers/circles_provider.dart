import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../services/circles_api_service.dart';
import '../services/notification_service.dart';

const _uuid = Uuid();

const _avatars = ['🌿', '🍃', '✨', '🌙', '🔥', '💫'];

class CircleProfile {
  final String userId;
  final String displayName;
  final String avatar;
  const CircleProfile({required this.userId, required this.displayName, required this.avatar});
}

class CirclesProvider extends ChangeNotifier {
  CircleProfile? _profile;
  List<Map<String, dynamic>> _circles = [];
  final bool _loading = false;

  CircleProfile? get profile => _profile;
  List<Map<String, dynamic>> get circles => _circles;
  bool get loading => _loading;
  bool get hasProfile => _profile != null && _profile!.displayName.isNotEmpty;
  List<String> get avatarOptions => _avatars;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('circles_user_id');
    if (userId == null) {
      userId = _uuid.v4();
      await prefs.setString('circles_user_id', userId);
    }
    final name = prefs.getString('circles_display_name') ?? '';
    final avatar = prefs.getString('circles_avatar') ?? _avatars[0];
    if (name.isNotEmpty) {
      _profile = CircleProfile(userId: userId, displayName: name, avatar: avatar);
      await _loadCircles();
    } else {
      _profile = CircleProfile(userId: userId, displayName: '', avatar: avatar);
    }
    notifyListeners();
  }

  Future<void> saveProfile(String displayName, String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('circles_display_name', displayName);
    await prefs.setString('circles_avatar', avatar);
    _profile = CircleProfile(userId: _profile!.userId, displayName: displayName, avatar: avatar);
    await _loadCircles();
    notifyListeners();
  }

  Future<void> _loadCircles() async {
    if (_profile == null) return;
    _circles = await AppDatabase.getCirclesForUser(_profile!.userId);
    notifyListeners();
  }

  Future<void> reload() => _loadCircles();

  Future<String> createCircle(String name, String emoji) async {
    final id = _uuid.v4();
    final token = _randomToken();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Server first — throws on failure so we don't create an orphaned local record
    await CirclesApiService.createCircle(
      id: id,
      ownerId: _profile!.userId,
      name: name,
      emoji: emoji,
      inviteToken: token,
    );

    await AppDatabase.insertCircle({
      'id': id,
      'name': name,
      'emoji': emoji,
      'owner_id': _profile!.userId,
      'invite_token': token,
      'created_at': now,
    });
    await AppDatabase.insertMember({
      'circle_id': id,
      'user_id': _profile!.userId,
      'display_name': _profile!.displayName,
      'avatar': _profile!.avatar,
      'joined_at': now,
    });
    await _loadCircles();
    return id;
  }

  Future<Map<String, dynamic>?> getCircle(String id) => AppDatabase.getCircle(id);

  // Resolves via the API — source of truth for cross-device invite validation
  Future<Map<String, dynamic>?> getCircleByToken(String token) =>
      CirclesApiService.getCircleByToken(token);

  // Fetches from API, caches to local SQLite, fires notification for new shares from others
  Future<List<Map<String, dynamic>>> getShares(String circleId) async {
    try {
      final apiShares = await CirclesApiService.getShares(circleId);
      final circle = await AppDatabase.getCircle(circleId);
      final circleName = circle?['name'] as String? ?? 'your circle';

      for (final share in apiShares) {
        final isNew = await AppDatabase.getShareById(share['id'] as String) == null;
        await AppDatabase.insertShare({
          'id': share['id'] as String,
          'circle_id': share['circle_id'] as String,
          'sharer_id': share['sharer_id'] as String,
          'type': share['type'] as String,
          'payload': share['payload'] as String,
          'note': share['note'] as String? ?? '',
          'timestamp': int.parse(share['timestamp'].toString()),
        });
        if (isNew && share['sharer_id'] != _profile?.userId) {
          final sharerName = share['display_name'] as String? ?? 'Someone';
          await NotificationService.showShareNotification(sharerName, circleName);
        }
      }
      return apiShares.map((s) => {
        ...s,
        'timestamp': int.parse(s['timestamp'].toString()),
      }).toList();
    } catch (_) {
      return AppDatabase.getShares(circleId);
    }
  }

  Future<List<Map<String, dynamic>>> getMembers(String circleId) => AppDatabase.getMembers(circleId);
  Future<List<Map<String, dynamic>>> getComments(String shareId) => AppDatabase.getComments(shareId);

  Future<List<Map<String, dynamic>>> getReactions(String shareId) async {
    try {
      final share = await AppDatabase.getShareById(shareId);
      if (share == null) return AppDatabase.getReactions(shareId);
      final circleId = share['circle_id'] as String;
      final apiReactions = await CirclesApiService.getReactions(shareId, circleId);
      final isMyShare = share['sharer_id'] == _profile?.userId;
      for (final r in apiReactions) {
        final isNew = await AppDatabase.insertReactionIfNew({
          'share_id': r['share_id'] as String,
          'user_id':  r['user_id']  as String,
          'type':     r['type']     as String,
        });
        if (isNew && isMyShare && r['user_id'] != _profile?.userId) {
          final circle = await AppDatabase.getCircle(circleId);
          final circleName = circle?['name'] as String? ?? 'your circle';
          await NotificationService.showReactionNotification(circleName);
        }
      }
      return apiReactions;
    } catch (_) {
      return AppDatabase.getReactions(shareId);
    }
  }

  Future<void> addShare({
    required String circleId,
    required String type,
    required Map<String, dynamic> payload,
    required String note,
  }) async {
    final payloadStr = jsonEncode(payload);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final shareId = await CirclesApiService.createShare(
      circleId: circleId,
      sharerId: _profile!.userId,
      displayName: _profile!.displayName,
      type: type,
      payload: payloadStr,
      note: note,
      timestamp: timestamp,
    );
    // Cache locally using the server-assigned id
    await AppDatabase.insertShare({
      'id': shareId ?? _uuid.v4(),
      'circle_id': circleId,
      'sharer_id': _profile!.userId,
      'type': type,
      'payload': payloadStr,
      'note': note,
      'timestamp': timestamp,
    });
  }

  Future<void> toggleReaction(String shareId, String type) async {
    // Optimistic local toggle + async API call
    await AppDatabase.toggleReaction(shareId, _profile!.userId, type);
    // Find which circle this share belongs to for the API path
    final share = await AppDatabase.getShareById(shareId);
    if (share != null) {
      final circleId = share['circle_id'] as String;
      CirclesApiService.toggleReaction(
        circleId: circleId,
        shareId: shareId,
        userId: _profile!.userId,
        type: type,
      );
    }
  }

  Future<void> addComment(String shareId, String text) async {
    await AppDatabase.insertComment({
      'id': _uuid.v4(),
      'share_id': shareId,
      'user_id': _profile!.userId,
      'display_name': _profile!.displayName,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<String> getInviteLink(String circleId) async {
    final circle = await AppDatabase.getCircle(circleId);
    final token = circle?['invite_token'] as String? ?? '';
    return 'cannaguide://app/circles/join?id=$circleId&token=$token';
  }

  Future<JoinResult> requestToJoin(String circleId, String token, String displayName) async {
    if (_profile == null) return JoinResult.needsProfile;
    if (await AppDatabase.isMember(circleId, _profile!.userId)) return JoinResult.alreadyMember;
    try {
      final result = await CirclesApiService.createJoinRequest(
        circleId: circleId,
        deviceId: _profile!.userId,
        displayName: displayName,
      );
      if (result == 'not_found') return JoinResult.invalidToken;
      return JoinResult.requested;
    } catch (_) {
      return JoinResult.networkError;
    }
  }

  Future<void> deleteCircle(String circleId) async {
    await CirclesApiService.deleteCircle(
      circleId: circleId,
      ownerDeviceId: _profile!.userId,
    );
    await AppDatabase.deleteCircleAndRelated(circleId);
    await _loadCircles();
  }

  // Called after a successful join to persist the circle locally so it shows in the list
  Future<void> saveJoinedCircle(Map<String, dynamic> circle, String displayName) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await AppDatabase.insertCircle({
      'id': circle['id'] as String,
      'name': circle['name'] as String,
      'emoji': circle['emoji'] as String? ?? '🌿',
      'owner_id': circle['owner_id'] as String,
      'invite_token': circle['invite_token'] as String,
      'created_at': now,
    });
    await AppDatabase.insertMember({
      'circle_id': circle['id'] as String,
      'user_id': _profile!.userId,
      'display_name': displayName,
      'avatar': _profile!.avatar,
      'joined_at': now,
    });
    await _loadCircles();
  }

  Future<void> approveRequest(String circleId, String userId, String displayName) async {
    await CirclesApiService.approveRequest(
      circleId: circleId,
      deviceId: userId,
      ownerDeviceId: _profile!.userId,
    );
    await AppDatabase.insertMember({
      'circle_id': circleId,
      'user_id': userId,
      'display_name': displayName,
      'avatar': _avatars[0],
      'joined_at': DateTime.now().millisecondsSinceEpoch,
    });
    await AppDatabase.deletePendingRequest(circleId, userId);
  }

  Future<void> declineRequest(String circleId, String userId) async {
    await CirclesApiService.declineRequest(
      circleId: circleId,
      deviceId: userId,
      ownerDeviceId: _profile!.userId,
    );
    await AppDatabase.deletePendingRequest(circleId, userId);
  }

  // Pending requests now come from the server
  Future<List<Map<String, dynamic>>> getPendingRequests(String circleId) =>
      CirclesApiService.getPendingRequests(
        circleId: circleId,
        ownerDeviceId: _profile?.userId ?? '',
      );

  static String _randomToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final seed = DateTime.now().microsecondsSinceEpoch;
    final rand = List.generate(8, (i) => chars[(seed ~/ (i + 1)) % chars.length]);
    return rand.join();
  }
}

enum JoinResult { requested, alreadyMember, pending, invalidToken, needsProfile, networkError }
