import 'package:flutter/material.dart';
import 'package:step_logger/models/step_logger_config.dart';
import 'package:step_logger/models/step_session.dart';
import 'package:step_logger/step_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the StepTrackerPlugin with configuration

  await StepTrackerPlugin.initialize(
    config: const StepLoggerConfig(
      androidNotificationTitle: 'My Example Step Tracker',
      androidNotificationContent: 'Tracking your steps in the background',
      //Note: Every Notifications can be removed in Android 14+ by the user
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
  int _totalSteps = 0;
  int _sessionSteps = 0;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupListeners();
  }

  Future<void> _loadInitialData() async {
    _totalSteps = await StepTrackerPlugin.getTotalSteps();
    _sessionSteps = await StepTrackerPlugin.getSessionSteps();
    _isTracking = await StepTrackerPlugin.isTracking();
    setState(() {});
  }

  void _setupListeners() {
    StepTrackerPlugin.stepUpdates.listen((update) {
      setState(() {
        _totalSteps = update.totalSteps;
        _sessionSteps = update.sessionSteps;
        _isTracking = update.isTracking;
      });
    });
  }

  @override
  void dispose() {
    StepTrackerPlugin.stopStepTracking();
    super.dispose();
  }

  Future<List<StepSession>> _loadSessionHistory() async {
    final sessions = await StepTrackerPlugin.getSessionHistory();
    // Handle session history data
    return sessions;
  }

  void _clearSessionHistory() async {
    await StepTrackerPlugin.clearSessionHistory();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Total Steps: $_totalSteps',
              style: const TextStyle(fontSize: 24)),
          Text('Session Steps: $_sessionSteps',
              style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 20),
          _isTracking
              ? ElevatedButton(
                  onPressed: () => StepTrackerPlugin.stopStepTracking(),
                  child: const Text('Stop Tracking'),
                )
              : ElevatedButton(
                  onPressed: () => StepTrackerPlugin.startStepTracking(),
                  child: const Text('Start Tracking'),
                ),
          const SizedBox(
            height: 20,
          ),
          ElevatedButton(
            onPressed: _clearSessionHistory,
            child: const Text('Clear Session History'),
          ),
          const SizedBox(height: 20),
          FutureBuilder(
              future: StepTrackerPlugin.isBackgroundServiceRunning(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  final isRunning = snapshot.data ?? false;
                  return Text(
                    'Background Service is ${isRunning ? 'Running' : 'Stopped'}',
                    style: const TextStyle(fontSize: 18),
                  );
                } else {
                  return const CircularProgressIndicator();
                }
              }),
          const SizedBox(height: 20),
          FutureBuilder(
              future: _loadSessionHistory(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final sessions = snapshot.data!;
                  return ListView.builder(
                      shrinkWrap: true,
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return ListTile(
                          title: Text('Steps: ${session.steps}'),
                          subtitle: Text(
                              'Duration: ${session.startTime} - ${session.endTime}'),
                        );
                      });
                } else {
                  return const CircularProgressIndicator();
                }
              })
        ],
      ),
    );
  }
}
