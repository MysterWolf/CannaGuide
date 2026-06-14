import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';

class CirclesApiService {
  static Map<String, String> _headers({String? deviceId}) => {
    'Content-Type': 'application/json',
    'x-api-secret': kCirclesApiSecret,
    if (deviceId != null) 'x-device-id': deviceId,
  };

  static Future<void> createCircle({
    required String id,
    required String ownerId,
    required String name,
    required String emoji,
    required String inviteToken,
  }) async {
    final res = await http.post(
      Uri.parse('$kCirclesApiBase/circles'),
      headers: _headers(),
      body: jsonEncode({
        'id': id,
        'owner_id': ownerId,
        'name': name,
        'emoji': emoji,
        'invite_token': inviteToken,
      }),
    );
    if (res.statusCode != 201) {
      throw Exception('Failed to create circle: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Map<String, dynamic>?> getCircleByToken(String token) async {
    final res = await http.get(
      Uri.parse('$kCirclesApiBase/circles/token/$token'),
      headers: _headers(),
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw Exception('API error ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<String> createJoinRequest({
    required String circleId,
    required String deviceId,
    required String displayName,
  }) async {
    final res = await http.post(
      Uri.parse('$kCirclesApiBase/circles/$circleId/requests'),
      headers: _headers(),
      body: jsonEncode({'device_id': deviceId, 'display_name': displayName}),
    );
    if (res.statusCode == 404) return 'not_found';
    if (res.statusCode == 201) return 'ok';
    throw Exception('API error ${res.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests({
    required String circleId,
    required String ownerDeviceId,
  }) async {
    final res = await http.get(
      Uri.parse('$kCirclesApiBase/circles/$circleId/requests'),
      headers: _headers(deviceId: ownerDeviceId),
    );
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['requests'] as List).cast<Map<String, dynamic>>();
  }

  static Future<bool> approveRequest({
    required String circleId,
    required String deviceId,
    required String ownerDeviceId,
  }) async {
    final res = await http.post(
      Uri.parse('$kCirclesApiBase/circles/$circleId/requests/$deviceId/approve'),
      headers: _headers(deviceId: ownerDeviceId),
    );
    return res.statusCode == 200;
  }

  static Future<bool> deleteCircle({
    required String circleId,
    required String ownerDeviceId,
  }) async {
    final res = await http.delete(
      Uri.parse('$kCirclesApiBase/circles/$circleId'),
      headers: _headers(deviceId: ownerDeviceId),
    );
    return res.statusCode == 200;
  }

  static Future<bool> declineRequest({
    required String circleId,
    required String deviceId,
    required String ownerDeviceId,
  }) async {
    final res = await http.delete(
      Uri.parse('$kCirclesApiBase/circles/$circleId/requests/$deviceId'),
      headers: _headers(deviceId: ownerDeviceId),
    );
    return res.statusCode == 200;
  }

  // ── Shares ─────────────────────────────────────────────────────────────────

  static Future<String?> createShare({
    required String circleId,
    required String sharerId,
    required String displayName,
    required String type,
    required String payload,
    required String note,
    required int timestamp,
  }) async {
    final res = await http.post(
      Uri.parse('$kCirclesApiBase/circles/$circleId/shares'),
      headers: _headers(),
      body: jsonEncode({
        'sharer_id': sharerId,
        'display_name': displayName,
        'type': type,
        'payload': payload,
        'note': note,
        'timestamp': timestamp,
      }),
    );
    if (res.statusCode != 201) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['id'] as String?;
  }

  static Future<List<Map<String, dynamic>>> getShares(String circleId) async {
    final res = await http.get(
      Uri.parse('$kCirclesApiBase/circles/$circleId/shares'),
      headers: _headers(),
    );
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['shares'] as List).cast<Map<String, dynamic>>();
  }

  // ── Reactions ──────────────────────────────────────────────────────────────

  static Future<void> toggleReaction({
    required String circleId,
    required String shareId,
    required String userId,
    required String type,
  }) async {
    await http.post(
      Uri.parse('$kCirclesApiBase/circles/$circleId/shares/$shareId/reactions'),
      headers: _headers(),
      body: jsonEncode({'user_id': userId, 'type': type}),
    );
  }

  static Future<List<Map<String, dynamic>>> getReactions(String shareId, String circleId) async {
    final res = await http.get(
      Uri.parse('$kCirclesApiBase/circles/$circleId/shares/$shareId/reactions'),
      headers: _headers(),
    );
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['reactions'] as List).cast<Map<String, dynamic>>();
  }
}
