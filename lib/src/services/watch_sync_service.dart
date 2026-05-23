import 'dart:async';

import 'package:flutter/services.dart';

import '../models/fitness_models.dart';

class WatchSyncService {
  WatchSyncService({MethodChannel? methodChannel, EventChannel? eventChannel})
    : _methodChannel =
          methodChannel ?? const MethodChannel('codex_fitness/watch_sync'),
      _eventChannel =
          eventChannel ?? const EventChannel('codex_fitness/watch_events');

  static const int schemaVersion = 1;

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<Map<String, dynamic>>? _events;

  Stream<Map<String, dynamic>> get events {
    return _events ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) {
          if (event is! Map) return false;
          return event['type'] == 'watchWorkoutCompleted';
        })
        .map((event) {
          return (event as Map).cast<String, dynamic>();
        });
  }

  Map<String, dynamic> buildWorkoutPayload({
    required PlannedWorkout workout,
    WorkoutLog? activeLog,
    DateTime? sentAt,
  }) {
    return {
      'schemaVersion': schemaVersion,
      'sentAt': (sentAt ?? DateTime.now()).toIso8601String(),
      'workout': workout.toJson(),
      if (activeLog != null) 'activeLog': activeLog.toJson(),
    };
  }

  Future<String> syncWorkout({
    required PlannedWorkout workout,
    WorkoutLog? activeLog,
  }) async {
    final result = await _methodChannel.invokeMethod<String>(
      'syncWorkout',
      buildWorkoutPayload(workout: workout, activeLog: activeLog),
    );
    return result ?? 'watch_sync_sent';
  }

  Future<void> markCompletionHandled(String completionId) async {
    await _methodChannel.invokeMethod<void>('markCompletionHandled', {
      'completionId': completionId,
    });
  }
}
