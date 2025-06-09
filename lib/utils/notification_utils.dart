import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationUtils {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<bool> initialize({
    final String? initialNotificationTitle,
    final String? androidNotificationIcon,
  }) async {
    try {
      AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings(
              androidNotificationIcon ?? 'ic_notification');

      await _notifications.initialize(
        InitializationSettings(android: initializationSettingsAndroid),
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
        importance: Importance.max,
        priority: Priority.max,
        ongoing: true,
        autoCancel: false,
        enableVibration: true,
        playSound: false,
        visibility: NotificationVisibility.public,
        // Critical for non-dismissable notifications:
        channelShowBadge: false,
        fullScreenIntent: true, // Makes it more persistent
        timeoutAfter: null, // Never times out
        showWhen: false,
        when: null,
        additionalFlags: Int32List.fromList([
          1 << 2, // FLAG_NO_CLEAR - This is crucial
        ]),
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
