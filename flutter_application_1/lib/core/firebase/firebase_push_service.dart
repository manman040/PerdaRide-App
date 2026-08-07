import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';

import '../notifications/local_notification_service.dart';
import '../settings/app_settings_controller.dart';
import 'firebase_auth_repository.dart';
import 'firebase_database_repository.dart';
import 'perdaride_firebase.dart';

class FirebasePushService {
  FirebasePushService._();

  static final FirebasePushService instance = FirebasePushService._();

  final _firebase = PerdaRideFirebase.instance;
  final _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } catch (_) {
      return;
    }

    final authRepository = FirebaseAuthRepository(_firebase);
    final databaseRepository = FirebaseDatabaseRepository(_firebase);
    final user = authRepository.currentUser;
    if (user == null) return;

    String? token;
    try {
      token = await _messaging.getToken();
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    } catch (_) {
      return;
    }
    if (token != null && token.isNotEmpty) {
      try {
        await databaseRepository.updateData('users/${user.uid}', {
          'fcmToken': token,
          'fcmUpdatedAt': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    var path = 'user_notifications/${user.uid}';
    try {
      final userProfile = await databaseRepository.getData('users/${user.uid}');
      final userType = userProfile.value is Map
          ? (userProfile.value as Map)['userType']?.toString().toLowerCase()
          : null;
      if (userType == 'driver') {
        path = 'driver_notifications/${user.uid}';
      }
    } catch (_) {}

    FirebaseMessaging.onMessage.listen((message) async {
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';

      try {
        await databaseRepository.pushData(path, {
          'title': title,
          'body': body,
          'read': false,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'source': 'push_foreground',
        });
      } catch (_) {}
    });

    _listenForLiveNotifications(databaseRepository, path);
  }

  void _listenForLiveNotifications(
    FirebaseDatabaseRepository databaseRepository,
    String path,
  ) {
    final attachedAt = DateTime.now().millisecondsSinceEpoch;
    databaseRepository.watchChildAdded(path).listen((event) {
      if (!AppSettingsController.instance.value.notificationsEnabled) return;

      final value = event.snapshot.value;
      if (value is! Map) return;

      final createdAt = value['createdAt'];
      final createdAtMs = createdAt is num ? createdAt.toInt() : 0;
      if (createdAtMs < attachedAt) return;

      final title = (value['title'] ?? 'Notification').toString();
      final body = (value['body'] ?? '').toString();
      LocalNotificationService.instance.show(title: title, body: body);
    });
  }
}
