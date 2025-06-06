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

class StepServiceAndroid extends StepTrackerPlatform {
  final StreamController<StepUpdate> _stepUpdateController =
      StreamController<StepUpdate>.broadcast();

  late final SharedPreferences _prefs;
  late final StepLoggerConfig _config;
  StreamSubscription<StepCount>? _stepCountStream;
  late final AppLifecycleListener _appLifecycleListener;

  // Tracking state
  int _totalStepsFromSystem = 0;
  int _totalSteps = 0;
  int _sessionSteps = 0;
  int _initialSteps = -1;
  bool _isTracking = false;
  final List<StepSession> _sessions = [];
  int _retryCount = 1;
  bool _appInForeground = true;
  DateTime? _lastUpdateTime;
  Timer? _stepRefreshTimer;

  @override
  Future<bool> initialize({StepLoggerConfig? config}) async {
    try {
      _config = config ?? const StepLoggerConfig();
      _prefs = await SharedPreferences.getInstance();

      await NotificationUtils.initialize(
        androidNotificationIcon: _config.androidNotificationIcon,
        initialNotificationTitle: _config.trackingNotificationTitle,
      );
      await _loadPersistedData();
      await _verifyPermissions();

      // Initialize app lifecycle listener
      _appLifecycleListener = AppLifecycleListener(
        onResume: _handleAppResumed,
        onPause: _handleAppPaused,
        onDetach: _handleAppDetached,
      );

      // Setup periodic refresh when in foreground
      _setupStepRefreshTimer();

      // Restart tracking if it was active before app restart
      if (_isTracking) {
        await _restartTracking();
      }

      return true;
    } catch (e) {
      debugPrint('StepTracker initialization error: $e');
      return false;
    }
  }

  @override
  Future<bool> dispose() async {
    try {
      _appLifecycleListener.dispose();
      await _stepCountStream?.cancel();
      await _stepUpdateController.close();
      return true;
    } on Exception catch (e) {
      debugPrint('StepTracker dispose error: $e');
      return false;
    }
  }

  @override
  Future<bool> startStepTracking() async {
    if (_isTracking) return true;

    try {
      // Verify all required permissions
      if (!await _verifyPermissions()) {
        debugPrint('Permissions not granted. Cannot start tracking.');
        return false;
      }

      // Initialize tracking state
      await _prefs.setBool('isTracking', true);
      await _prefs.setInt('initialSteps', -1);
      await _prefs.setInt('sessionSteps', 0);

      _isTracking = true;
      _initialSteps = -1;
      _sessionSteps = 0;

      // Start step counting
      await _restartTracking();

      // Start background services
      await BackgroundService.start(_config);

      // Show start tracking notification
      if (_config.enableTrackingNotification) {
        await NotificationUtils.showTrackingNotification(
          androidNotificationTitle: _config.trackingNotificationTitle,
          androidNotificationContent: _config.trackingNotificationContent,
        );
      }

      _emitUpdate();
      return true;
    } catch (e) {
      debugPrint('Error starting step tracking: $e');
      _isTracking = false;
      await _prefs.setBool('isTracking', false);
      return false;
    }
  }

  /// Stops the step tracking session.
  ///
  /// This will:
  /// 1. Save current session if steps were recorded
  /// 2. Update tracking state
  /// 3. Cancel subscriptions
  /// 4. Stop background services
  ///
  /// Returns `true` if successful, `false` otherwise
  @override
  Future<bool> stopStepTracking() async {
    if (!_isTracking) return true;

    try {
      // Save current session if steps were recorded
      if (_sessionSteps > 0) {
        await _saveCurrentSession();
      }

      // Update tracking state
      _isTracking = false;
      await _prefs.setBool('isTracking', false);
      await _prefs.setInt('initialSteps', -1);
      await _prefs.setInt('sessionSteps', 0);

      // Clean up resources
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

  // ==================== Lifecycle Handlers ====================

  void _handleAppResumed() {
    debugPrint('App resumed - reconnecting step stream');
    _appInForeground = true;
    _setupStepRefreshTimer();
    _restartTracking();
    _emitUpdate();
  }

  void _handleAppPaused() {
    debugPrint('App paused - pausing step stream');
    _appInForeground = false;
    _stepRefreshTimer?.cancel();
    _stepCountStream?.pause();
  }

  /// Handles app detach event
  void _handleAppDetached() {
    debugPrint('App detached - cleaning up');
    _appInForeground = false;
    _stepRefreshTimer?.cancel();
    _stepCountStream?.cancel();
  }

  // ==================== Step Stream Management ====================

  void _setupStepRefreshTimer() {
    _stepRefreshTimer?.cancel();
    if (_isTracking && _appInForeground) {
      _stepRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (_isTracking) {
          _emitUpdate();
          // Force a step count refresh if no updates recently
          if (_lastUpdateTime == null ||
              DateTime.now().difference(_lastUpdateTime!) >
                  const Duration(seconds: 10)) {
            _restartTracking();
          }
        }
      });
    }
  }

  // ==================== Core Functionality ====================

  /// Restarts the step counting stream with error recovery
  Future<void> _restartTracking() async {
    try {
      await _stepCountStream?.cancel();

      _stepCountStream = Pedometer.stepCountStream.listen(
        (event) {
          _lastUpdateTime = DateTime.now();
          _handleStepCount(event);
        },
        onError: (error) {
          debugPrint('Step stream error: $error');
          // Retry with exponential backoff
          Future.delayed(Duration(seconds: _retryCount * 2), _restartTracking);
          _retryCount = (_retryCount < 5) ? _retryCount + 1 : 5;
        },
        cancelOnError: false,
      );

      _retryCount = 1;
    } catch (e) {
      debugPrint('Error restarting tracking: $e');
    }
  }

  /// Handles incoming step count updates
  void _handleStepCount(StepCount event) async {
    if (!_isTracking) return;

    // Initialize step count if this is the first update
    if (_initialSteps == -1) {
      _initialSteps = event.steps;
      await _prefs.setInt('initialSteps', _initialSteps);
    }

    // Update step counts
    _totalStepsFromSystem = event.steps;
    _sessionSteps = event.steps - _initialSteps;
    _totalSteps = _sessions.fold(0, (sum, session) => sum + session.steps);

    // Persist updated counts
    await _prefs.setInt('totalSteps', _totalSteps);
    await _prefs.setInt('currentSteps', _totalStepsFromSystem);
    await _prefs.setInt('sessionSteps', _sessionSteps);

    _emitUpdate();
  }

  /// Saves the current tracking session
  Future<void> _saveCurrentSession() async {
    final session = StepSession(
      steps: _sessionSteps,
      startTime: DateTime.now().subtract(const Duration(minutes: 1)),
      endTime: DateTime.now(),
    );
    _sessions.add(session);
    _totalSteps += _sessionSteps;
    _sessionSteps = 0;
    await _saveSessions();
  }

  /// Verifies all required permissions
  Future<bool> _verifyPermissions() async {
    try {
      final statuses = await [
        Permission.activityRecognition,
        Permission.notification,
        Permission.ignoreBatteryOptimizations,
      ].request();

      return statuses[Permission.activityRecognition]?.isGranted == true &&
          statuses[Permission.notification]?.isGranted == true;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  /// Emits a step update through the stream controller
  void _emitUpdate() {
    if (_stepUpdateController.isClosed) return;

    _stepUpdateController.add(
      StepUpdate(
        totalSteps: _totalSteps + _sessionSteps,
        totalStepsFromSystem: _totalStepsFromSystem,
        sessionSteps: _sessionSteps,
        isTracking: _isTracking,
      ),
    );
  }

  // ==================== Public API ====================

  @override
  Future<bool> isTracking() async => _isTracking;

  @override
  Future<int> getTotalSteps() async {
    if (_totalSteps == 0 && _sessions.isNotEmpty) {
      _totalSteps = _sessions.fold(0, (sum, session) => sum + session.steps);
    }
    return _totalSteps;
  }

  @override
  Future<int> getTotalStepsFromSystem() async => _totalStepsFromSystem;

  @override
  Future<int> getSessionSteps() async => _sessionSteps;

  @override
  Stream<StepUpdate> get stepUpdates => _stepUpdateController.stream;

  @override
  Future<List<StepSession>> getSessionHistory() async => _sessions;

  @override
  Future<bool> clearSessionHistory() async {
    if (_isTracking) {
      debugPrint('Cannot clear session history while tracking is active.');
      return false;
    }
    _sessions.clear();
    await _prefs.remove('sessions');
    return true;
  }

  @override
  Future<bool> clearTotalSteps() async {
    if (_sessions.isEmpty && !_isTracking) {
      _totalSteps = 0;
      await _saveTotalSteps();
      return true;
    }
    debugPrint(
        'Session history not empty or tracking is active - skipping clear');
    return false;
  }

  @override
  Future<bool> isBackgroundServiceRunning() async =>
      await BackgroundService.isRunning();

  @override
  Future<bool> startBackgroundService() async =>
      await BackgroundService.start(_config);

  @override
  Future<bool> stopBackgroundService() async => await BackgroundService.stop();

  // ==================== Persistence Methods ====================

  /// Loads persisted data from shared preferences
  Future<void> _loadPersistedData() async {
    _isTracking = _prefs.getBool('isTracking') ?? false;
    _totalStepsFromSystem = _prefs.getInt('currentSteps') ?? 0;
    _totalSteps = _prefs.getInt('totalSteps') ?? 0;
    _sessionSteps = _prefs.getInt('sessionSteps') ?? 0;
    _initialSteps = _prefs.getInt('initialSteps') ?? -1;

    final sessions = _prefs.getStringList('sessions') ?? [];
    _sessions.clear();

    for (var session in sessions) {
      try {
        final decoded = jsonDecode(session);
        _sessions.add(StepSession.fromMap(Map<String, dynamic>.from(decoded)));
      } catch (e) {
        debugPrint('Error parsing session (skipping): $session');
      }
    }

    // Calculate total steps from sessions if not already loaded
    if (_totalSteps == 0 && _sessions.isNotEmpty) {
      _totalSteps = _sessions.fold(0, (sum, session) => sum + session.steps);
      await _saveTotalSteps();
    }
  }

  /// Saves sessions to persistent storage
  Future<void> _saveSessions() async {
    await _prefs.setStringList(
      'sessions',
      _sessions.map((s) => jsonEncode(s.toMap())).toList(),
    );
  }

  /// Saves total steps to persistent storage
  Future<void> _saveTotalSteps() async {
    await _prefs.setInt('totalSteps', _totalSteps);
  }

  // ==================== iOS Stubs ====================

  @override
  Future<bool> hasHealthKitPermission() {
    throw UnimplementedError('HealthKit is iOS-only');
  }

  @override
  Future<bool> requestHealthKitAuthorization() {
    throw UnimplementedError('HealthKit is iOS-only');
  }
}
