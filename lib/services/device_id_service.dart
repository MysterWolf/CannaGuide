import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const _key = 'stashpass_device_id';
  static const _uuid = Uuid();
  static String _deviceId = '';

  static String get deviceId => _deviceId;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_key, id);
    }
    _deviceId = id;
  }
}
