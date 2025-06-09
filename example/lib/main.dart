import 'package:flutter/material.dart';
import 'package:step_logger/models/step_logger_config.dart';
import 'package:step_logger/models/step_session.dart';
import 'package:step_logger/step_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the StepTrackerPlugin with configuration
  await StepLogger.initialize(
    config: const StepLoggerConfig(
      androidNotificationIcon: 'ic_notification', // For foreground notification
      /* 
        To change notification icon on Android for bg service, 
        just add drawable icon with name ic_bg_service_small.

        ## Create notification icon
        Open Android Studio> In the Project window, select the Android view> 
        Right-click the res folder and select New > Image Asset > Set 'Notification Icon' as icon type>
        Name it 'ic_bg_service_small' and save it.

        
        WARNING:
        Please make sure your project already use the version of gradle tools below:

        in android/build.gradle classpath 'com.android.tools.build:gradle:7.4.2'
        in android/build.gradle ext.kotlin_version = '1.8.10'
        in android/gradle/wrapper/gradle-wrapper.properties distributionUrl=https\://services.gradle.org/distributions/gradle-7.5-all.zip
              
        Please refer: https://pub.dev/packages/flutter_background_service#android
       */

      enableTrackingNotification:
          true, // Works for both platforms, but disabling is limited for Android as background service should show notification.
      trackingNotificationTitle: 'My Example Step Tracker',
      trackingNotificationContent: 'Tracking your steps in the background',
      // Note: All notifications can be removed in Android 14+ by the user
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Step Tracker')),
        body: const StepTrackerScreen(),
      ),
    );
  }
}

class StepTrackerScreen extends StatefulWidget {
  const StepTrackerScreen({super.key});

  @override
  StepTrackerScreenState createState() => StepTrackerScreenState();
}

class StepTrackerScreenState extends State<StepTrackerScreen> {
  final ScrollController _scrollController = ScrollController();

  int _totalSteps = 0;
  int _totalStepsFromSystem = 0;
  int _sessionSteps = 0;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupListeners();
  }

  Future<void> _loadInitialData() async {
    _totalSteps = await StepLogger.getTotalSteps();
    _totalStepsFromSystem = await StepLogger.getTotalStepsFromSystem();
    _sessionSteps = await StepLogger.getSessionSteps();
    _isTracking = await StepLogger.isTracking();
    setState(() {});
  }

  void _setupListeners() {
    StepLogger.stepUpdates.listen((update) {
      setState(() {
        _totalSteps = update.totalSteps;
        _totalStepsFromSystem = update.totalStepsFromSystem;
        _sessionSteps = update.sessionSteps;
        _isTracking = update.isTracking;
      });
    });
  }

  @override
  void dispose() {
    StepLogger.stopStepTracking();
    super.dispose();
  }

  Future<List<StepSession>> _loadSessionHistory() async {
    final sessions = await StepLogger.getSessionHistory();
    // Handle session history data
    return sessions;
  }

  void _clearSessionHistory() async {
    await StepLogger.clearSessionHistory();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'Total Steps (System): $_totalStepsFromSystem',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              'Total Steps: $_totalSteps',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              'Session Steps: $_sessionSteps',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 20),
            _isTracking
                ? ElevatedButton(
                    onPressed: () => StepLogger.stopStepTracking(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop),
                        SizedBox(width: 8),
                        Text('Stop Tracking'),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: () => StepLogger.startStepTracking(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.run_circle),
                        SizedBox(width: 8),
                        Text('Start Tracking'),
                      ],
                    ),
                  ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  StepLogger.clearTotalSteps();
                });
                // Only works if session history is empty
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.clear),
                  Text('Clear Total Steps'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _clearSessionHistory,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.clear, color: Colors.red),
                  Text(
                    'Clear Session History',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<bool>(
              future: StepLogger.isBackgroundServiceRunning(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  final isRunning = snapshot.data ?? false;
                  return Text(
                    'Background Service is ${isRunning ? 'Running' : 'Stopped'} *Status is only for Android*',
                    style: const TextStyle(fontSize: 10),
                  );
                } else {
                  return const CircularProgressIndicator();
                }
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 400, // Fixed height for the session history list
              child: FutureBuilder<List<StepSession>>(
                future: _loadSessionHistory(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    final sessions = snapshot.data!;
                    return Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return ListTile(
                            title: Text('Steps: ${session.steps}'),
                            subtitle: Text(
                              'Duration: ${session.startTime} - ${session.endTime}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    );
                  } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                    return const Center(child: Text('No session history.'));
                  } else {
                    return const Center(
                        child: Text('Failed to load session history.'));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
