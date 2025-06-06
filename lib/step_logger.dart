import 'dart:async';
import 'dart:io';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:step_logger/models/step_logger_config.dart';
import 'package:step_logger/models/step_session.dart';
import 'package:step_logger/services/step_service_android.dart';
import 'package:step_logger/services/step_service_ios.dart';

abstract class StepTrackerPlatform extends PlatformInterface {
  StepTrackerPlatform() : super(token: _token);
  static final Object _token = Object();

  // Default to Android (StepService) if not set
  static StepTrackerPlatform _instance =
      Platform.isAndroid ? StepServiceAndroid() : StepServiceIOS();

  static StepTrackerPlatform get instance => _instance;
  static set instance(StepTrackerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<bool> initialize({StepLoggerConfig? config});
  Future<bool> dispose();

  // Step tracking methods
  Future<bool> startStepTracking();
  Future<bool> stopStepTracking();
  Future<bool> isTracking();
  Future<bool> clearTotalSteps();
  Future<int> getTotalSteps();
  Future<int> getTotalStepsFromSystem();
  Future<int> getSessionSteps();

  Stream<StepUpdate> get stepUpdates;

  // Session history
  Future<List<StepSession>> getSessionHistory();
  Future<bool> clearSessionHistory();

  // Background service control
  Future<bool> isBackgroundServiceRunning();
  Future<bool> startBackgroundService();
  Future<bool> stopBackgroundService();

  // iOS-specific methods
  Future<bool> requestHealthKitAuthorization();
  Future<bool> hasHealthKitPermission();
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

  /// Gets total steps count from system
  static Future<int> getTotalStepsFromSystem() =>
      StepTrackerPlatform.instance.getTotalStepsFromSystem();

  /// Gets current session steps count
  static Future<int> getSessionSteps() =>
      StepTrackerPlatform.instance.getSessionSteps();

  /// Stream of step updates
  static Stream<StepUpdate> get stepUpdates =>
      StepTrackerPlatform.instance.stepUpdates;

  /// Gets session history
  static Future<List<StepSession>> getSessionHistory() =>
      StepTrackerPlatform.instance.getSessionHistory();

  /// Clear total steps
  static Future<bool> clearTotalSteps() =>
      StepTrackerPlatform.instance.clearTotalSteps();

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

  /// iOS-specific: Request HealthKit authorization
  static Future<bool> requestHealthKitAuthorization() {
    if (Platform.isIOS) {
      return StepTrackerPlatform.instance.requestHealthKitAuthorization();
    }
    return Future.value(false);
  }

  /// iOS-specific: Check if HealthKit permission is granted
  static Future<bool> hasHealthKitPermission() {
    if (Platform.isIOS) {
      return StepTrackerPlatform.instance.hasHealthKitPermission();
    }
    return Future.value(false);
  }
}

class StepUpdate {
  final int totalSteps;
  final int totalStepsFromSystem;
  final int sessionSteps;
  final bool isTracking;

  StepUpdate({
    required this.totalSteps,
    required this.totalStepsFromSystem,
    required this.sessionSteps,
    required this.isTracking,
  });
}
