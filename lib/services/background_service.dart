import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_logger/models/step_logger_config.dart';

class BackgroundService {
  static final _service = FlutterBackgroundService();

  /// [initialize] Initializes the background service.
  ///
  /// This must be called before any other methods can be used.
  ///
  /// The [autoStart] parameter specifies whether the service should be started
  /// automatically when the app is launched. If not specified, this defaults to
  /// `false`.
  ///
  /// The [notificationChannelId], [initialNotificationTitle], and
  /// [initialNotificationContent] parameters customize the notification that is
  /// displayed while the service is running. If not specified, these default to
  /// `"step_tracker_channel"`, `"Step Tracker"`, and `"Tracking your steps"`,
  /// respectively.
  ///
  /// The [foregroundServiceNotificationId] parameter specifies the ID of the
  /// notification that is displayed while the service is running. If not
  /// specified, this defaults to `1`.
  ///
  /// Returns `true` if the service is initialized successfully, `false` otherwise.
  static Future<bool> initialize(StepLoggerConfig config) async {
    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'step_tracker_channel',
          initialNotificationTitle:
              config.androidNotificationTitle ?? 'Step Tracker',
          initialNotificationContent:
              config.androidNotificationContent ?? 'Tracking your steps',
          foregroundServiceNotificationId: 1,
        ),
        iosConfiguration: IosConfiguration(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'bg_service_config',
          jsonEncode({
            'title': config.androidNotificationTitle,
            'content': config.androidNotificationContent,
          }));
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isRunning() async {
    try {
      return await _service.isRunning();
    } catch (e) {
      return false;
    }
  }

  static Future<bool> start(StepLoggerConfig config) async {
    try {
      if (!await isRunning()) {
        await initialize(config);
        await _service.startService();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> stop() async {
    try {
      if (await isRunning()) {
        _service.invoke('stopService');
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// This is the entry point for the background service.
  ///
  /// sets the foreground notification title and content. It also listens
  /// for the 'stopService' event and stops the service when it is received.
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('bg_service_config');
    Map<String, dynamic> configData = {};

    if (configJson != null) {
      try {
        configData = jsonDecode(configJson);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing config: $e');
        }
      }
    }

    final title = configData['title'] ?? 'Step Tracker';
    final content =
        configData['content'] ?? 'Tracking your steps in background';

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(title: title, content: content);
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }
}
