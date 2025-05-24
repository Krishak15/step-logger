Flutter Step Tracker Plugin (Android)
A robust step tracking plugin with background service support for Android.

Installation
Add to pubspec.yaml:

yaml
dependencies:
  step_tracker_plugin: ^1.0.0

#Android Setup

Add to AndroidManifest.xml:
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<service
    android:name="com.example.step_tracker_plugin.StepTrackerService"
    android:foregroundServiceType="health"
    android:exported="false"/>

Set minSdkVersion 21 in app/build.gradle

Usage

// Initialize
await StepTrackerPlugin.initialize();

// Start tracking
await StepTrackerPlugin.startStepTracking();

// Get steps
int steps = await StepTrackerPlugin.getTotalSteps();

// Stream updates
StepTrackerPlugin.stepUpdates.listen((update) {
  print('Steps: ${update.totalSteps}');
});

// Stop tracking
await StepTrackerPlugin.stopStepTracking();
Required Permissions
Request these at runtime:


await [
  Permission.activityRecognition,
  Permission.notification,
].request();

Features
Background step counting

Battery-efficient implementation

Session tracking

Foreground service support

Works when app is closed

Troubleshooting
Ensure permissions are granted

Disable battery optimization for your app

Test on physical device

Check Logcat for errors

For full example see example/ directory.

