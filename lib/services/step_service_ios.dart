import 'dart:async';
import 'package:flutter/material.dart';
import 'package:step_logger/models/step_logger_config.dart';
import 'package:step_logger/models/step_session.dart';
import 'package:step_logger/step_logger.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:step_logger/utils/notification_utils_ios.dart';

/// A step tracking service implementation for iOS using HealthKit and Pedometer.
///
/// `StepServiceIOS` manages step tracking sessions, session history, and persistence
/// for iOS devices. It interacts with HealthKit to fetch step data, handles session
/// state, and provides real-time updates via streams. The service supports background
/// recovery, auto-saving, and notification integration.
///
/// ### Features
/// - Tracks steps using HealthKit and Pedometer.
/// - Manages session state, including start/stop, session steps, and total steps.
/// - Persists session data and history using `SharedPreferences`.
/// - Recovers steps taken while the app was not running.
/// - Emits updates via a broadcast stream.
/// - Handles app lifecycle events to ensure accurate step counting.
/// - Integrates with iOS notifications for tracking status.
///
/// ### Usage
/// - Call [initialize] to set up the service.
/// - Use [startStepTracking] and [stopStepTracking] to control tracking sessions.
/// - Listen to [stepUpdates] for real-time step data.
/// - Access session history with [getSessionHistory].
/// - Clear session history or steps using [clearSessionHistory] and [clearTotalSteps].
///
/// ### Important Methods
/// - [initialize]: Initializes the service and loads persisted data.
/// - [startStepTracking]: Starts a new step tracking session.
/// - [stopStepTracking]: Stops the current session and saves it to history.
/// - [fetchTotalStepsFromSystem]: Fetches the current day's steps from HealthKit.
/// - [getTotalSteps]: Returns the total steps counted across all sessions.
/// - [getSessionSteps]: Returns the steps counted in the current session.
/// - [stepUpdates]: Stream of [StepUpdate] events for UI updates.
/// - [clearSessionHistory]: Clears all session history while preserving total steps.
/// - [requestHealthKitAuthorization]: Requests HealthKit permissions.
///
/// ### Lifecycle Handling
/// Implements [WidgetsBindingObserver] to respond to app lifecycle changes,
/// ensuring step data is accurate even when the app is backgrounded or resumed.
///
/// ### Persistence
/// Uses `SharedPreferences` to persist session state and history, enabling
/// recovery after app restarts or interruptions.
///
/// ### Notifications
/// Integrates with [NotificationUtilsIOS] to display tracking notifications.
///

class StepServiceIOS extends StepTrackerPlatform with WidgetsBindingObserver {
  // Step tracking and health data
  final Health _health = Health();
  Stream<StepCount>? _stepCountStream;

  // Step counters
  int _totalStepsFromSystem = 0;
  int _totalSteps = 0;
  int _sessionSteps = 0;

  // Session state
  int? _sessionStartTotalSteps;
  int? _lastSavedTotalSteps;
  bool _isTracking = false;
  DateTime? _sessionStartTime;

  // Session history
  final List<StepSession> _sessions = [];

  // Persistence
  static const String _prefsKey = 'step_session_data';

  // Autosave
  Timer? _autoSaveTimer;

  // Stream for updates
  final StreamController<StepUpdate> _stepUpdateController =
      StreamController<StepUpdate>.broadcast();

  // Notifications
  final NotificationUtilsIOS _notificationUtilsIOS = NotificationUtilsIOS();

  // Configuration
  late StepLoggerConfig _config;

  /// Initializes the step tracking service.
  ///
  /// This method sets up the necessary observers, initializes notification utilities,
  /// and prepares the step tracking session. It loads any persisted data and handles
  /// recovery of interrupted sessions if needed. The initial total steps are calculated
  /// from the session history.
  ///
  /// [config] - Optional configuration for the step logger. If not provided, a default
  /// configuration is used.
  ///
  /// Returns a [Future] that completes with `true` when initialization is successful.

  @override
  Future<bool> initialize({StepLoggerConfig? config}) async {
    WidgetsBinding.instance.addObserver(this);
    _config = config ?? const StepLoggerConfig();

    _notificationUtilsIOS.initializeNotifications();
    await _initStepTracking();
    await _loadPersistedData();

    if (_isTracking && _sessionStartTime == null) {
      await _resetTrackingState();
    } else if (_isTracking) {
      await _recoverInterruptedSession();
    }
    // Calculate initial total steps from history
    _totalSteps = _calculateTotalFromSessions();
    return true;
  }

  @override
  Future<bool> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _stepUpdateController.close();
    return true;
  }

  /// Recovers steps that were taken while the app was not running.
  ///
  /// This method fetches the current total step count from HealthKit and compares it
  /// to the last saved total steps. If there is a difference (i.e., steps were taken
  /// while the app was killed or in the background), it adds the missed steps to the
  /// current session's step count and logs the recovery.
  ///
  /// This ensures that the step count remains accurate even if the app was interrupted.
  /// This method is called when the app is resumed from the background.
  Future<void> _recoverInterruptedSession() async {
    // Get current steps from HealthKit
    await fetchTotalStepsFromSystem();
    // Calculate steps taken while app was killed
    if (_lastSavedTotalSteps != null) {
      final missedSteps = _totalStepsFromSystem - _lastSavedTotalSteps!;
      if (missedSteps > 0) {
        _sessionSteps += missedSteps;
        debugPrint('Recovered $missedSteps steps from background');
      }
    }

    // Update last saved steps and persist
    _lastSavedTotalSteps = _totalStepsFromSystem;
    await _persistAllData();

    _stepUpdateController.add(StepUpdate(
      totalSteps: _totalSteps,
      totalStepsFromSystem: _totalStepsFromSystem,
      sessionSteps: _sessionSteps,
      isTracking: _isTracking,
    ));

    // Restart autosave
    _startAutoSave();
  }

  Future<void> _persistAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // Save tracking state
    await prefs.setString(
        '$_prefsKey-tracking',
        jsonEncode({
          'isTracking': _isTracking,
          'startTime': _sessionStartTime?.toIso8601String(),
          'sessionSteps': _sessionSteps,
          'startTotalSteps': _sessionStartTotalSteps,
          'lastSavedTotalSteps': _lastSavedTotalSteps,
          'totalSteps': _totalSteps,
        }));

    // Save session history
    await prefs.setString('$_prefsKey-history',
        jsonEncode(_sessions.map((s) => s.toMap()).toList()));
  }

  /// Starts step tracking on iOS devices.
  ///
  /// Initializes the tracking session by setting the tracking flag, recording the session start time,
  /// and resetting the session step count. Fetches the current total steps from the system and stores
  /// them as the session's starting step count. Persists all relevant data and starts the auto-save mechanism.
  /// Displays a notification to indicate that step tracking has started, and emits an update event.
  ///
  /// Returns `true` if tracking was successfully started or is already active.
  ///
  /// Returns a [Future] that completes with a boolean indicating the success of the operation.
  @override
  Future<bool> startStepTracking() async {
    if (_isTracking) return true;

    _isTracking = true;
    _sessionStartTime = DateTime.now();
    _sessionSteps = 0;
    await fetchTotalStepsFromSystem();
    _sessionStartTotalSteps = _totalStepsFromSystem;
    _lastSavedTotalSteps = _totalStepsFromSystem;

    await _persistAllData();
    _startAutoSave();

    if (_config.enableTrackingNotification) {
      _notificationUtilsIOS.showStartTrackingNotification(
        notificationTitle: _config.trackingNotificationTitle,
        notificationContent: _config.trackingNotificationContent,
      );
    }

    _emitUpdate();
    return true;
  }

  /// Loads persisted tracking data from shared preferences.
  ///
  /// This method retrieves the tracking state, including session start time,
  /// session steps, total steps, and other related information from local storage.
  /// If the persisted data is found and valid, it initializes the corresponding
  /// fields with the loaded values. If the data is corrupted or cannot be parsed,
  /// it logs an error and resets the tracking state to default values.
  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load tracking state (including totalSteps)
    final trackingJson = prefs.getString('$_prefsKey-tracking');
    if (trackingJson != null) {
      try {
        final data = jsonDecode(trackingJson);
        _isTracking = data['isTracking'] ?? false;
        _sessionStartTime = data['startTime'] != null
            ? DateTime.parse(data['startTime'])
            : null;
        _sessionSteps = data['sessionSteps'] ?? 0;
        _sessionStartTotalSteps = data['startTotalSteps'];
        _lastSavedTotalSteps = data['lastSavedTotalSteps'];
        _totalSteps = data['totalSteps'] ?? 0; // Load preserved total
      } catch (e) {
        debugPrint('Error loading tracking state: $e');
        await _resetTrackingState();
      }
    }

    // Load session history (separate from totalSteps)
    final historyJson = prefs.getString('$_prefsKey-history');
    if (historyJson != null) {
      try {
        final List<dynamic> historyData = jsonDecode(historyJson);
        _sessions.clear();
        _sessions.addAll(historyData.map((item) => StepSession.fromMap(item)));
      } catch (e) {
        debugPrint('Error loading session history: $e');
      }
    }
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isTracking) {
        await _persistSession();
      }
    });
  }

  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  /// Stops the step tracking session.
  ///
  /// If a session is currently active and steps have been recorded, the session is saved
  /// with its start time, end time, and step count. The tracking state and related variables
  /// are reset, all data is persisted, and auto-save is stopped. An update event is emitted.
  ///
  /// Returns `true` if the operation completes successfully or if tracking was not active.
  @override
  Future<bool> stopStepTracking() async {
    if (!_isTracking) return true;

    // Save completed session
    if (_sessionSteps > 0) {
      _sessions.add(StepSession(
        startTime: _sessionStartTime!,
        endTime: DateTime.now(),
        steps: _sessionSteps,
      ));
    }

    // Reset tracking state
    _isTracking = false;
    _sessionSteps = 0;
    _sessionStartTime = null;
    _sessionStartTotalSteps = null;
    _lastSavedTotalSteps = null;

    await _persistAllData();

    _stopAutoSave();
    _emitUpdate();

    return true;
  }

  @override
  Future<bool> isTracking() async => _isTracking;

  @override
  Future<int> getTotalSteps() async {
    return _totalSteps;
  }

  @override
  Future<int> getSessionSteps() async => _sessionSteps;

  @override
  Future<int> getTotalStepsFromSystem() async {
    await fetchTotalStepsFromSystem();
    return _totalStepsFromSystem;
  }

  @override
  Future<bool> clearTotalSteps() async {
    if (_sessions.isNotEmpty) {
      debugPrint('Session history not empty - skipping clear');
      return false;
    }
    try {
      // Reset only session-related values
      _sessionSteps = 0;
      _sessionStartTime = null;
      _sessionStartTotalSteps = null;
      _lastSavedTotalSteps = null;

      // Update persistence
      await _persistTrackingState();

      debugPrint('Cleared session steps (no history present)');
      _emitUpdate();
      return true;
    } catch (e) {
      debugPrint('Error clearing session steps: $e');
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground
        if (_isTracking) _calculateMissedSteps();
        break;
      case AppLifecycleState.paused:
        // App is in background
        _persistSession();
        break;
      case AppLifecycleState.detached:
        // App is killed (not always reliable on iOS)
        break;
      default:
        break;
    }
  }

  @override
  Stream<StepUpdate> get stepUpdates => _stepUpdateController.stream;

  @override
  Future<List<StepSession>> getSessionHistory() async => _sessions;

  @override
  Future<bool> clearSessionHistory() async {
    return await _clearSessionHistory();
  }

  @override
  Future<bool> isBackgroundServiceRunning() async => false;

  @override
  Future<bool> startBackgroundService() async => true;

  @override
  Future<bool> stopBackgroundService() async => true;

  @override
  Future<bool> requestHealthKitAuthorization() async {
    return await _health.requestAuthorization([HealthDataType.STEPS]);
  }

  @override
  Future<bool> hasHealthKitPermission() async {
    return await _health.hasPermissions([HealthDataType.STEPS]).then(
        (permissions) => permissions ?? false);
  }

  int _calculateTotalFromSessions() {
    // Calculate total steps by summing all sessions
    final sessionTotal =
        _sessions.fold(0, (sum, session) => sum + session.steps);

    // Add current session steps if tracking is active
    _totalSteps = sessionTotal + (_isTracking ? _sessionSteps : 0);
    return _totalSteps;
  }

  Future<void> _initStepTracking() async {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream?.listen(_onStepCount);
    await fetchTotalStepsFromSystem();
  }

  void _onStepCount(StepCount event) {
    _totalStepsFromSystem = event.steps;
    if (_isTracking && _sessionStartTotalSteps != null) {
      _sessionSteps = _totalStepsFromSystem - _sessionStartTotalSteps!;
    }

    _calculateTotalFromSessions();

    _stepUpdateController.add(StepUpdate(
      totalSteps: _totalSteps,
      totalStepsFromSystem: _totalStepsFromSystem,
      sessionSteps: _sessionSteps,
      isTracking: _isTracking,
    ));
  }

  /// Fetches the total number of steps from the system's health data for the current day.
  ///
  /// This method requests authorization to access step data, retrieves all step entries
  /// from the start of the current day until now, and calculates the total steps.
  /// If the fetched total steps exceed the previously recorded value, it updates the internal
  /// step count. If tracking is active, it manages session step counts and persists the session state.
  /// Handles any errors by logging them for debugging purposes.
  Future<void> fetchTotalStepsFromSystem() async {
    try {
      final types = [HealthDataType.STEPS];
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);

      bool requested = await _health.requestAuthorization(types);
      if (!requested) return;

      List<HealthDataPoint> steps = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: types,
      );

      int totalSteps = steps.fold(0, (sum, data) {
        if (data.value is NumericHealthValue) {
          final numericValue = data.value as NumericHealthValue;
          return sum + numericValue.numericValue.round();
        }
        return sum;
      });

      if (_totalStepsFromSystem < totalSteps) {
        _totalStepsFromSystem = totalSteps;
      }

      if (_isTracking) {
        if (_sessionStartTotalSteps == null) {
          _sessionStartTotalSteps = _totalStepsFromSystem;
          _sessionSteps = 0;
        } else if (_lastSavedTotalSteps != null) {
          final stepsSinceLast = _totalStepsFromSystem - _lastSavedTotalSteps!;
          if (stepsSinceLast > 0) {
            _sessionSteps += stepsSinceLast;
          }
        }
      }

      _lastSavedTotalSteps = _totalStepsFromSystem;
      await _persistSession();
    } catch (e) {
      debugPrint('Error fetching steps: $e');
    }
  }

  /// Clears the session history while preserving the total steps and tracking state.
  ///
  /// This method first checks if tracking is currently active. If so, it logs a message
  /// and returns `false` to prevent clearing the history during an active session.
  /// Otherwise, it clears the in-memory session list and removes the session history
  /// from persistent storage, but keeps the total steps and tracking state intact.
  /// After updating the state, it emits an update event.
  ///
  /// Returns `true` if the session history was successfully cleared, or `false` if
  /// an error occurred or tracking is active.
  Future<bool> _clearSessionHistory() async {
    if (_isTracking) {
      debugPrint('Cannot clear history while tracking is active');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      // Clear only the session history while preserving totalSteps
      _sessions.clear();
      await prefs.remove('$_prefsKey-history');

      // Keep tracking state and totalSteps intact
      await _persistTrackingState();

      _emitUpdate();
      return true;
    } catch (e) {
      debugPrint('Error clearing history: $e');
      return false;
    }
  }

  Future<void> _persistTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_prefsKey-tracking',
        jsonEncode({
          'isTracking': _isTracking,
          'startTime': _sessionStartTime?.toIso8601String(),
          'sessionSteps': _sessionSteps,
          'startTotalSteps': _sessionStartTotalSteps,
          'lastSavedTotalSteps': _lastSavedTotalSteps,
          'totalSteps': _totalSteps, // This preserves the total
        }));
  }

  Future<void> _resetTrackingState() async {
    _isTracking = false;
    _sessionSteps = 0;
    _sessionStartTime = null;
    _sessionStartTotalSteps = null;
    _lastSavedTotalSteps = null;
    await _persistSession();
  }

  /// Calculates and adds any steps that were taken while the app was in the background.
  ///
  /// This method checks if step tracking is active and if there is a previously saved
  /// total step count. It fetches the current total steps from the system, computes the
  /// difference (steps taken during background), and if any steps were missed, adds them
  /// to the current session. The updated session is then persisted and listeners are notified.
  ///
  /// Returns a [Future] that completes when the calculation and persistence are done.
  Future<void> _calculateMissedSteps() async {
    if (!_isTracking || _lastSavedTotalSteps == null) return;

    await fetchTotalStepsFromSystem();
    final stepsDuringBackground = _totalStepsFromSystem - _lastSavedTotalSteps!;

    if (stepsDuringBackground > 0) {
      _sessionSteps += stepsDuringBackground;
      debugPrint('Added $stepsDuringBackground steps from background');
      _lastSavedTotalSteps = _totalStepsFromSystem;
      await _persistSession();
      _emitUpdate();
    }
  }

  /// Emits an updated [StepUpdate] event to the [_stepUpdateController].
  ///
  /// The emitted [StepUpdate] contains the current total steps, total steps from the system,
  /// session steps, and tracking status. If tracking is active, the session steps are added
  /// to the total steps before emitting.
  void _emitUpdate() {
    _stepUpdateController.add(StepUpdate(
      totalSteps: _totalSteps + (_isTracking ? _sessionSteps : 0),
      totalStepsFromSystem: _totalStepsFromSystem,
      sessionSteps: _sessionSteps,
      isTracking: _isTracking,
    ));
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'isTracking': _isTracking,
        'startTime': _sessionStartTime?.toIso8601String(),
        'sessionSteps': _sessionSteps,
        'startTotalSteps': _sessionStartTotalSteps,
        'lastSavedTotalSteps': _lastSavedTotalSteps,
      };
      await prefs.setString(_prefsKey, jsonEncode(data));
      debugPrint('Persisted session state');
    } catch (e) {
      debugPrint('Error persisting session: $e');
    }
  }
}
