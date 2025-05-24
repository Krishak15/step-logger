import 'package:flutter_background_service/flutter_background_service.dart';

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
  static Future<bool> initialize() async {
    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'step_tracker_channel',
          initialNotificationTitle: 'Step Tracker',
          initialNotificationContent: 'Tracking your steps',
          foregroundServiceNotificationId: 1,
        ),
        iosConfiguration: IosConfiguration(),
      );
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

  static Future<bool> start() async {
    try {
      if (!await isRunning()) {
        await initialize();
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

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Step Tracker",
        content: "Tracking your steps in background",
      );
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }
}
