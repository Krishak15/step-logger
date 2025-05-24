import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationUtils {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<bool> initialize({
    final String? initialNotificationTitle,
  }) async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      await _notifications.initialize(
        const InitializationSettings(android: initializationSettingsAndroid),
      );

      AndroidNotificationChannel channel = AndroidNotificationChannel(
        'step_tracker_channel',
        initialNotificationTitle ?? 'Step Tracker',
        importance: Importance.high,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> showTrackingNotification({
    final String? androidNotificationTitle,
    final String? androidNotificationContent,
  }) async {
    try {
      AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'step_tracker_channel',
        androidNotificationTitle ?? 'Step Tracker',
        channelDescription: androidNotificationContent ?? 'Tracking your steps',
        usesChronometer: true,
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
      );

      await _notifications.show(
        1,
        'Step Tracker Active',
        'Tracking your steps in the background',
        NotificationDetails(android: androidNotificationDetails),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> cancelNotification() async {
    try {
      await _notifications.cancel(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
