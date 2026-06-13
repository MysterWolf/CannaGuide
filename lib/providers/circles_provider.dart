import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';

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

  Future<String> createCircle(String name, String emoji, List<String> memberNames) async {
    final id = _uuid.v4();
    final token = _randomToken();
    final now = DateTime.now().millisecondsSinceEpoch;
    await AppDatabase.insertCircle({
      'id': id,
      'name': name,
      'emoji': emoji,
      'owner_id': _profile!.userId,
      'invite_token': token,
      'created_at': now,
    });
    // Add owner
    await AppDatabase.insertMember({
      'circle_id': id,
      'user_id': _profile!.userId,
      'display_name': _profile!.displayName,
      'avatar': _profile!.avatar,
      'joined_at': now,
    });
    // Add other members by display name
    for (final name in memberNames) {
      await AppDatabase.insertMember({
        'circle_id': id,
        'user_id': _uuid.v4(),
        'display_name': name,
        'avatar': _avatars[0],
        'joined_at': now,
      });
    }
    await _loadCircles();
    return id;
  }

  Future<Map<String, dynamic>?> getCircle(String id) => AppDatabase.getCircle(id);
  Future<Map<String, dynamic>?> getCircleByToken(String token) => AppDatabase.getCircleByToken(token);

  Future<List<Map<String, dynamic>>> getShares(String circleId) => AppDatabase.getShares(circleId);
  Future<List<Map<String, dynamic>>> getMembers(String circleId) => AppDatabase.getMembers(circleId);
  Future<List<Map<String, dynamic>>> getComments(String shareId) => AppDatabase.getComments(shareId);
  Future<List<Map<String, dynamic>>> getReactions(String shareId) => AppDatabase.getReactions(shareId);

  Future<void> addShare({
    required String circleId,
    required String type,
    required Map<String, dynamic> payload,
    required String note,
  }) async {
    await AppDatabase.insertShare({
      'id': _uuid.v4(),
      'circle_id': circleId,
      'sharer_id': _profile!.userId,
      'type': type,
      'payload': jsonEncode(payload),
      'note': note,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> toggleReaction(String shareId, String type) =>
      AppDatabase.toggleReaction(shareId, _profile!.userId, type);

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

  Future<JoinResult> requestToJoin(String circleId, String token) async {
    if (_profile == null || !hasProfile) return JoinResult.needsProfile;
    final circle = await AppDatabase.getCircle(circleId);
    if (circle == null) return JoinResult.invalidToken;
    if (circle['invite_token'] != token) return JoinResult.invalidToken;
    if (await AppDatabase.isMember(circleId, _profile!.userId)) return JoinResult.alreadyMember;
    if (await AppDatabase.hasPendingRequest(circleId, _profile!.userId)) return JoinResult.pending;
    await AppDatabase.insertPendingRequest({
      'circle_id': circleId,
      'user_id': _profile!.userId,
      'display_name': _profile!.displayName,
      'requested_at': DateTime.now().millisecondsSinceEpoch,
    });
    return JoinResult.requested;
  }

  Future<void> approveRequest(String circleId, String userId, String displayName) async {
    await AppDatabase.insertMember({
      'circle_id': circleId,
      'user_id': userId,
      'display_name': displayName,
      'avatar': _avatars[0],
      'joined_at': DateTime.now().millisecondsSinceEpoch,
    });
    await AppDatabase.deletePendingRequest(circleId, userId);
  }

  Future<void> declineRequest(String circleId, String userId) =>
      AppDatabase.deletePendingRequest(circleId, userId);

  Future<List<Map<String, dynamic>>> getPendingRequests(String circleId) =>
      AppDatabase.getPendingRequests(circleId);

  static String _randomToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final seed = DateTime.now().microsecondsSinceEpoch;
    final rand = List.generate(8, (i) => chars[(seed ~/ (i + 1)) % chars.length]);
    return rand.join();
  }
}

enum JoinResult { requested, alreadyMember, pending, invalidToken, needsProfile }
