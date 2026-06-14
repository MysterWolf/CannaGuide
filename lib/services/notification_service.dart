import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static int _nextId = 0;

  static const _channelId = 'circles_channel';
  static const _channelName = 'Circle Updates';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
  );

  static Future<void> init() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initSettings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.high,
      ),
    );
    // Request permission (Android 13+)
    await android?.requestNotificationsPermission();
  }

  static Future<void> showShareNotification(String sharerName, String circleName) async {
    await _plugin.show(
      _nextId++,
      circleName,
      '$sharerName shared something',
      _details,
    );
  }

  static Future<void> showReactionNotification(String circleName) async {
    await _plugin.show(
      _nextId++,
      circleName,
      'Someone reacted to your share',
      _details,
    );
  }
}
