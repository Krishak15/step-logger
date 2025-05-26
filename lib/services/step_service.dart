import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_logger/models/step_logger_config.dart';
import 'package:step_logger/models/step_session.dart';
import 'package:step_logger/services/background_service.dart';
import 'package:step_logger/step_logger.dart';
import 'package:step_logger/utils/notification_utils.dart';

class StepService extends StepTrackerPlatform {
  final StreamController<StepUpdate> _stepUpdateController =
      StreamController<StepUpdate>.broadcast();
  late SharedPreferences _prefs;
  late StepLoggerConfig _config;

  StreamSubscription<StepCount>? _stepCountStream;
  int _totalSteps = 0;
  int _sessionSteps = 0;
  int _initialSteps = -1;
  bool _isTracking = false;
  final List<StepSession> _sessions = [];

  /// Initializes the StepService by setting up shared preferences,
  /// initializing notifications, loading persisted data, and checking permissions.
  ///
  /// Returns `true` if initialization is successful, or `false` if an error occurs.
  @override
  Future<bool> initialize({StepLoggerConfig? config}) async {
    try {
      _config = config ?? const StepLoggerConfig();
      _prefs = await SharedPreferences.getInstance();

      await NotificationUtils.initialize(
        initialNotificationTitle: _config.androidNotificationTitle,
      );
      await _loadPersistedData();
      await _checkPermissions();

      return true;
    } catch (e) {
      debugPrint('StepTracker initialization error: $e');
      return false;
    }
  }

  // get notification title and content from the config
  // String get androidNotificationTitle =>
  //     NotificationConfig().androidNotificationTitle ?? 'Step Tracker';
  // String get androidNotificationContent =>
  //     NotificationConfig().androidNotificationContent ?? 'Tracking your steps';

  /// Starts the step tracking session.
  ///
  /// If tracking is already active, returns `true` immediately. If not, sets
  /// the tracking flag to `true`, resets the initial step count to -1, and
  /// starts the step count stream. If successful, starts the background
  /// service, shows a notification, emits an update, and returns `true`.
  /// Otherwise, sets the tracking flag to `false`, logs the error, and
  /// returns `false`.
  @override
  Future<bool> startStepTracking() async {
    if (_isTracking) return true;
    bool permissionsGranted = false;
    try {
      permissionsGranted = await Permission.activityRecognition.isGranted &&
          await Permission.notification.isGranted;
      await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }

    if (!permissionsGranted) {
      await _checkPermissions();
      debugPrint('Permissions not granted. Cannot start tracking.');
      return false;
    }

    try {
      await _prefs.setBool('isTracking', true);
      await _prefs.setInt('initialSteps', -1);
      await _prefs.setInt('sessionSteps', 0);

      _isTracking = true;
      _initialSteps = -1;
      _sessionSteps = 0;

      _stepCountStream ??= Pedometer.stepCountStream.listen(_handleStepCount);
      _stepCountStream?.onError((error) {
        debugPrint('Error in step count stream: $error');
      });
      await BackgroundService.start(
        _config,
      );

      await NotificationUtils.showTrackingNotification(
        androidNotificationTitle: _config.androidNotificationTitle,
        androidNotificationContent: _config.androidNotificationContent,
      );
      _emitUpdate();
      return true;
    } catch (e) {
      debugPrint('Error starting step tracking: $e');
      _isTracking = false;
      return false;
    }
  }

  /// Stops the step tracking session.
  ///
  /// If tracking is active, it saves the session data if there are any steps
  /// recorded, updates the persistent storage to reflect that tracking is no
  /// longer active, and cancels ongoing subscriptions and notifications. Emits
  /// an update after stopping the tracking. Returns `true` if successful, or
  /// `false` if an error occurs.
  @override
  Future<bool> stopStepTracking() async {
    if (!_isTracking) return true;

    try {
      if (_sessionSteps > 0) {
        final session = StepSession(
          steps: _sessionSteps,
          startTime: DateTime.now().subtract(const Duration(minutes: 1)),
          endTime: DateTime.now(),
        );
        _sessions.add(session);
        await _saveSessions();
      }

      _isTracking = false;
      await _prefs.setBool('isTracking', false);
      await _prefs.setInt('initialSteps', -1);
      await _prefs.setInt('sessionSteps', 0);

      await _stepCountStream?.cancel();
      _stepCountStream = null;
      await BackgroundService.stop();
      await NotificationUtils.cancelNotification();

      _emitUpdate();
      return true;
    } catch (e) {
      debugPrint('Error stopping step tracking: $e');
      return false;
    }
  }

  @override
  Future<bool> isTracking() async => _isTracking;

  @override
  Future<int> getTotalSteps() async => _totalSteps;

  @override
  Future<int> getSessionSteps() async => _sessionSteps;

  @override
  Stream<StepUpdate> get stepUpdates => _stepUpdateController.stream;

  @override
  Future<List<StepSession>> getSessionHistory() async => _sessions;

  @override
  Future<bool> clearSessionHistory() async {
    _sessions.clear();
    await _prefs.remove('sessions');
    return true;
  }

  @override
  Future<bool> isBackgroundServiceRunning() async =>
      await BackgroundService.isRunning();

  @override
  Future<bool> startBackgroundService() async =>
      await BackgroundService.start(_config);

  @override
  Future<bool> stopBackgroundService() async => await BackgroundService.stop();

  void _handleStepCount(StepCount event) async {
    if (!_isTracking) return;

    if (_initialSteps == -1) {
      _initialSteps = event.steps;
      await _prefs.setInt('initialSteps', _initialSteps);
    }

    _totalSteps = event.steps;
    _sessionSteps = event.steps - _initialSteps;

    await _prefs.setInt('currentSteps', _totalSteps);
    await _prefs.setInt('sessionSteps', _sessionSteps);

    _emitUpdate();
  }

  /// Loads persisted data from shared preferences into the service.
  ///
  /// This method retrieves and sets the tracking state, total steps, session
  /// steps, and initial steps from shared preferences. It also loads any
  /// persisted step sessions, attempting to parse them as JSON. If parsing
  /// fails due to improper formatting, it attempts a fallback parsing method.
  /// Successfully parsed sessions are added to the internal session list.
  /// Errors during parsing are logged and the session is skipped.
  Future<void> _loadPersistedData() async {
    _isTracking = _prefs.getBool('isTracking') ?? false;
    _totalSteps = _prefs.getInt('currentSteps') ?? 0;
    _sessionSteps = _prefs.getInt('sessionSteps') ?? 0;
    _initialSteps = _prefs.getInt('initialSteps') ?? -1;

    final sessions = _prefs.getStringList('sessions') ?? [];
    _sessions.clear();

    for (var session in sessions) {
      try {
        final decoded = jsonDecode(session);
        _sessions.add(StepSession.fromMap(Map<String, dynamic>.from(decoded)));
      } catch (e) {
        try {
          // Fallback for improperly stored sessions
          final fixedSession = session
              .replaceAll('{', '{"')
              .replaceAll('}', '"}')
              .replaceAll(': ', '": "')
              .replaceAll(', ', '", "');
          final decoded = jsonDecode(fixedSession);
          _sessions
              .add(StepSession.fromMap(Map<String, dynamic>.from(decoded)));
        } catch (e) {
          debugPrint('Error parsing session (skipping): $session');
        }
      }
    }
  }

  Future<void> _saveSessions() async {
    await _prefs.setStringList(
      'sessions',
      _sessions.map((s) => jsonEncode(s.toMap())).toList(),
    );
  }

  Future<void> _checkPermissions() async {
    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  void _emitUpdate() {
    _stepUpdateController.add(
      StepUpdate(
        totalSteps: _totalSteps,
        sessionSteps: _sessionSteps,
        isTracking: _isTracking,
      ),
    );
  }
}

class NotificationConfig {
  final String? androidNotificationTitle;
  final String? androidNotificationContent;

  NotificationConfig({
    this.androidNotificationTitle,
    this.androidNotificationContent,
  });
}
