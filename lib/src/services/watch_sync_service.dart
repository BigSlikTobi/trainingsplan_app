import 'dart:async';

import 'package:flutter/services.dart';

import '../models/fitness_models.dart';

class WatchSyncService {
  WatchSyncService({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _methodChannel =
          methodChannel ?? const MethodChannel('t4l_trainer/watch_sync'),
      _eventChannel =
          eventChannel ?? const EventChannel('t4l_trainer/watch_events');

  static const int schemaVersion = 1;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<Map<String, dynamic>>? _events;

  Stream<Map<String, dynamic>> get events {
    return _events ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is Map && event['type'] is String)
        .map((event) => (event as Map).cast<String, dynamic>());
  }

  Map<String, dynamic> buildWorkoutPayload({
    required PlannedWorkout workout,
    WorkoutLog? activeLog,
    WorkoutLog? completedLog,
    DateTime? sentAt,
  }) {
    return {
      'schemaVersion': schemaVersion,
      'sentAt': (sentAt ?? DateTime.now()).toIso8601String(),
      'workout': workout.toJson(),
      if (activeLog != null) 'activeLog': activeLog.toJson(),
      if (completedLog != null) 'completedLog': completedLog.toJson(),
    };
  }

  Future<String> syncWorkout({
    required PlannedWorkout workout,
    WorkoutLog? activeLog,
    WorkoutLog? completedLog,
  }) async {
    final result = await _methodChannel.invokeMethod<String>(
      'syncWorkout',
      buildWorkoutPayload(
        workout: workout,
        activeLog: activeLog,
        completedLog: completedLog,
      ),
    );
    return result ?? 'watch_sync_sent';
  }

  Future<void> markCompletionHandled(String completionId) async {
    await _methodChannel.invokeMethod<void>('markCompletionHandled', {
      'completionId': completionId,
    });
  }

  Future<void> endWatchWorkout(String workoutId) async {
    if (workoutId.isEmpty) return;
    await _methodChannel.invokeMethod<void>('endWatchWorkout', {
      'workoutId': workoutId,
    });
  }
}
