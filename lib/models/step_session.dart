class StepSession {
  final int steps;
  final DateTime startTime;
  final DateTime endTime;

  StepSession({
    required this.steps,
    required this.startTime,
    required this.endTime,
  });

  factory StepSession.fromMap(Map<String, dynamic> map) {
    return StepSession(
      steps: map['steps'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'steps': steps,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
    };
  }
}