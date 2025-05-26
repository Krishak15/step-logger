import 'dart:async';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:step_logger/models/step_logger_config.dart';
import 'package:step_logger/models/step_session.dart';
import 'package:step_logger/services/step_service.dart';

abstract class StepTrackerPlatform extends PlatformInterface {
  StepTrackerPlatform() : super(token: _token);
  static final Object _token = Object();

  static StepTrackerPlatform _instance = StepService();
  static StepTrackerPlatform get instance => _instance;
  static set instance(StepTrackerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> initialize({StepLoggerConfig? config});

  // Step tracking methods
  Future<bool> startStepTracking();
  Future<bool> stopStepTracking();
  Future<bool> isTracking();
  Future<int> getTotalSteps();
  Future<int> getSessionSteps();
  Stream<StepUpdate> get stepUpdates;

  // Session history
  Future<List<StepSession>> getSessionHistory();
  Future<bool> clearSessionHistory();

  // Background service control
  Future<bool> isBackgroundServiceRunning();
  Future<bool> startBackgroundService();
  Future<bool> stopBackgroundService();
}

class StepLogger {
  /// Initializes the step tracker plugin
  static Future<bool> initialize({StepLoggerConfig? config}) =>
      StepTrackerPlatform.instance.initialize(config: config);

  /// Starts step tracking session
  static Future<bool> startStepTracking() =>
      StepTrackerPlatform.instance.startStepTracking();

  /// Stops step tracking session
  static Future<bool> stopStepTracking() =>
      StepTrackerPlatform.instance.stopStepTracking();

  /// Checks if tracking is active
  static Future<bool> isTracking() => StepTrackerPlatform.instance.isTracking();

  /// Gets total steps count
  static Future<int> getTotalSteps() =>
      StepTrackerPlatform.instance.getTotalSteps();

  /// Gets current session steps count
  static Future<int> getSessionSteps() =>
      StepTrackerPlatform.instance.getSessionSteps();

  /// Stream of step updates
  static Stream<StepUpdate> get stepUpdates =>
      StepTrackerPlatform.instance.stepUpdates;

  /// Gets session history
  static Future<List<StepSession>> getSessionHistory() =>
      StepTrackerPlatform.instance.getSessionHistory();

  /// Clears session history
  static Future<bool> clearSessionHistory() =>
      StepTrackerPlatform.instance.clearSessionHistory();

  /// Checks if background service is running
  static Future<bool> isBackgroundServiceRunning() =>
      StepTrackerPlatform.instance.isBackgroundServiceRunning();

  /// Starts background service
  static Future<bool> startBackgroundService() =>
      StepTrackerPlatform.instance.startBackgroundService();

  /// Stops background service
  static Future<bool> stopBackgroundService() =>
      StepTrackerPlatform.instance.stopBackgroundService();
}

class StepUpdate {
  final int totalSteps;
  final int sessionSteps;
  final bool isTracking;

  StepUpdate({
    required this.totalSteps,
    required this.sessionSteps,
    required this.isTracking,
  });
}
