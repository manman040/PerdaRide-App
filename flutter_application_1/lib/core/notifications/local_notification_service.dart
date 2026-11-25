import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  int _nextId = 0;

  static const _channel = AndroidNotificationDetails(
    'ride_events',
    'Ride Updates',
    channelDescription: 'Booking status and chat updates for Urban Drive',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(initSettings);
    } catch (_) {}
  }

  Future<void> show({required String title, required String body}) async {
    try {
      await initialize();
      await _plugin.show(
        _nextId++,
        title,
        body,
        const NotificationDetails(android: _channel),
      );
    } catch (_) {}
  }
}
