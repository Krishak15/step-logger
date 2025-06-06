import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationUtilsIOS {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Future<void> initializeNotifications() async {
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  Future<void> showStartTrackingNotification(
      {String? notificationTitle, String? notificationContent}) async {
    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      iOS: iosNotificationDetails,
    );

    await _notificationsPlugin.show(
      0,
      notificationTitle ?? 'Step Tracking Started',
      notificationContent ?? 'Your step tracking session has begun',
      notificationDetails,
    );
  }
}
