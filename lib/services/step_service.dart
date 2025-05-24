import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_logger/models/step_session.dart';
import 'package:step_logger/services/background_service.dart';
import 'package:step_logger/step_logger.dart';
import 'package:step_logger/utils/notification_utils.dart';

class StepService extends StepTrackerPlatform {
  final StreamController<StepUpdate> _stepUpdateController =
      StreamController<StepUpdate>.broadcast();
  late SharedPreferences _prefs;
  late StreamSubscription<StepCount> _stepCountStream;
  int _totalSteps = 0;
  int _sessionSteps = 0;
  int _initialSteps = -1;
  bool _isTracking = false;
  final List<StepSession> _sessions = [];

  @override

  /// Initializes the StepService by setting up shared preferences,
  /// initializing notifications, loading persisted data, and checking permissions.
  ///
  /// Returns `true` if initialization is successful, or `false` if an error occurs.

  Future<bool> initialize({
    final String? initialNotificationTitle,
  }) async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await NotificationUtils.initialize(
        initialNotificationTitle: initialNotificationTitle,
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

    try {
      await _prefs.setBool('isTracking', true);
      await _prefs.setInt('initialSteps', -1);
      await _prefs.setInt('sessionSteps', 0);

      _isTracking = true;
      _initialSteps = -1;
      _sessionSteps = 0;

      _stepCountStream = Pedometer.stepCountStream.listen(_handleStepCount);
      await BackgroundService.start();

      await NotificationUtils.showTrackingNotification(
        // androidNotificationTitle: androidNotificationTitle,
        // androidNotificationContent: androidNotificationContent,
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

      await _stepCountStream.cancel();
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
      await BackgroundService.start();

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

  Future<void> _loadPersistedData() async {
    _isTracking = _prefs.getBool('isTracking') ?? false;
    _totalSteps = _prefs.getInt('currentSteps') ?? 0;
    _sessionSteps = _prefs.getInt('sessionSteps') ?? 0;
    _initialSteps = _prefs.getInt('initialSteps') ?? -1;

    final sessions = _prefs.getStringList('sessions') ?? [];
    _sessions.clear();
    for (var session in sessions) {
      try {
        _sessions.add(
          StepSession.fromMap(Map<String, dynamic>.from(jsonDecode(session))),
        );
      } catch (e) {
        debugPrint('Error parsing session: $e');
      }
    }
  }

  Future<void> _saveSessions() async {
    await _prefs.setStringList(
      'sessions',
      _sessions.map((s) => s.toMap().toString()).toList(),
    );
  }

  Future<void> _checkPermissions() async {
    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
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
