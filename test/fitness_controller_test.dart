import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/data/local_store.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/health_sync_service.dart';
import 'package:trainingsplan_app/src/services/local_bridge_service.dart';
import 'package:trainingsplan_app/src/services/watch_sync_service.dart';
import 'package:trainingsplan_app/src/state/fitness_controller.dart';

import 'helpers/sample_fitness_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logSet clamps RPE to the valid coaching scale', () async {
    final controller = FitnessController(store: _MemoryStore());
    await controller.load();
    final exercise = controller.nextWorkout!.exercises.first;

    await controller.logSet(exercise, 0, 10, 32);

    expect(controller.data.logs.single.sets.single.rpe, 10);
  });

  test(
    'completion prefers matched Apple Health workout over manual write',
    () async {
      final health = _MatchingHealthSync();
      final controller = FitnessController(
        store: _MemoryStore(),
        health: health,
      );
      await controller.load();
      final exercise = controller.nextWorkout!.exercises.first;

      await controller.logSet(exercise, 20, 8, 6);
      await controller.completeCurrentWorkout();

      final log = controller.data.logs.single;
      expect(log.healthWriteStatus, 'matched_apple_health_workout:FUNCTIONAL');
      expect(log.healthMetrics?.heartRateBpm, 124);
      expect(log.healthMetrics?.activeEnergyKcal, 96);
      expect(health.writeCount, 0);
    },
  );

  test('workout completion refreshes day context export', () async {
    final store = _MemoryStore();
    final health = _DayContextHealthSync();
    final controller = FitnessController(store: store, health: health);
    await controller.load();
    final exercise = controller.nextWorkout!.exercises.first;

    await controller.logSet(exercise, 20, 8, 6);
    await controller.completeCurrentWorkout();

    expect(store.jsonFiles, contains('day_context.json'));
    final payload = store.jsonFiles['day_context.json']!;
    expect(payload['schema'], 'day_context.v1');
    final summary = payload['activitySummary'] as Map<String, dynamic>;
    expect(summary['readStatus'], 'ok');
    expect(summary['steps'], 12000);
    final sessions = payload['activitySessions'] as List<dynamic>;
    expect(sessions.single, containsPair('activityType', 'RUNNING'));
  });

  test('imports meal analysis for review before saving nutrition', () async {
    final store = _MemoryStore()
      ..jsonFiles['nutrition_analysis_result.json'] = {
        'schema': 'nutrition_analysis_result.v1',
        'result': {
          'requestId': 'meal_request_test',
          'mealDescription': 'Chicken rice bowl',
          'calories': 780,
          'protein': 48,
          'carbs': 82,
          'fat': 28,
          'bodyWeightKg': 82,
          'confidence': .72,
          'target': {
            'dailyCalories': 2750,
            'protein': 175,
            'carbs': 320,
            'fat': 80,
            'goalMode': 'Codex inferred recomposition',
            'rationale': 'Training load supports maintenance.',
            'updatedAt': '2026-05-19T13:00:00.000',
            'source': 'Codex',
          },
        },
      };
    final health = _NutritionHealthSync();
    final controller = FitnessController(store: store, health: health);
    await controller.load();

    await controller.checkForNutritionAnalysisResult();

    expect(controller.pendingMealResult?.calories, 780);
    expect(controller.data.nutrition.first.calories, 2600);

    await controller.acceptMealAnalysis(
      calories: 800,
      protein: 50,
      carbs: 84,
      fat: 29,
      bodyWeightKg: 82.2,
      notes: 'Bigger rice portion.',
    );

    expect(controller.pendingMealResult, isNull);
    expect(controller.data.nutrition.first.calories, 800);
    expect(controller.data.profile.weightKg, 82.2);
    expect(controller.data.profile.nutritionTarget.dailyCalories, 2750);
    expect(health.nutritionWriteCount, 1);
    expect(
      controller.data.memories.any(
        (item) =>
            item.category == MemoryCategory.nutrition &&
            item.source == 'auto_nutrition' &&
            item.active,
      ),
      isTrue,
    );
    expect(
      store.jsonFiles.containsKey('nutrition_analysis_result.json'),
      isFalse,
    );
  });

  test('manual memory actions add edit toggle and delete entries', () async {
    final controller = FitnessController(store: _MemoryStore());
    await controller.load();

    await controller.addMemory(
      category: MemoryCategory.preference,
      title: 'Language',
      summary: 'Prefers concise German coaching.',
      markdown: 'Use direct cues during workouts.',
    );
    final added = controller.data.memories.first;

    expect(added.category, MemoryCategory.preference);
    expect(added.active, isTrue);

    await controller.toggleMemory(added.id, false);
    expect(controller.data.memories.first.active, isFalse);

    await controller.updateMemory(
      controller.data.memories.first.copyWith(
        title: 'Coaching language',
        summary: 'Prefers concise German coaching with direct cues.',
      ),
    );
    expect(controller.data.memories.first.title, 'Coaching language');

    await controller.deleteMemory(added.id);
    expect(
      controller.data.memories.any((item) => item.id == added.id),
      isFalse,
    );
  });

  test('imports coach memory wiki entries from exchange context', () async {
    final store = _MemoryStore()
      ..jsonFiles['day_context.json'] = {
        'schema': 'day_context.v1',
        'memoryWiki': {
          'entries': [
            {
              'category': 'constraint',
              'title': 'Right hip flexor',
              'summary': 'No sprints or split squats until pain-free.',
              'source': 'manual_codex_decision',
              'confidence': 1.0,
              'updatedAt': '2026-05-21T10:35:00+02:00',
            },
          ],
        },
      };
    final controller = FitnessController(store: store);

    await controller.load();
    await controller.importExchangeMemoryWiki();
    await controller.importExchangeMemoryWiki();

    final matches = controller.data.memories.where(
      (item) =>
          item.category == MemoryCategory.constraint &&
          item.source == 'manual_codex_decision' &&
          item.title == 'Right hip flexor',
    );
    expect(matches, hasLength(1));
    expect(store.saved?.memories.first.summary, contains('No sprints'));
  });

  test('bridge config persists outside fitness data', () async {
    final store = _MemoryStore();
    final controller = FitnessController(store: store);
    await controller.load();

    await controller.saveBridgeConfig(
      baseUrl: 'http://127.0.0.1:8787',
      token: '123-456',
    );

    expect(store.saved, isNull);
    expect(store.bridgeConfig.baseUrl, 'http://127.0.0.1:8787');
    expect(store.bridgeConfig.token, '123-456');
  });

  test(
    'server migration uploads full snapshot without mutating phone data',
    () async {
      final store = _MemoryStore();
      final bridge = _CapturingBridgeService();
      final controller = FitnessController(
        store: store,
        bridge: bridge,
        health: _DayContextHealthSync(),
      );
      await controller.load();
      final before = controller.data.toJson();

      await controller.saveBridgeConfig(
        baseUrl: 'http://127.0.0.1:8787',
        token: '123-456',
      );
      store.saved = null;
      await controller.migrateToServer();

      expect(controller.data.toJson(), before);
      expect(store.saved, isNull);
      expect(bridge.snapshot?['schema'], 't4l_app_snapshot.v1');
      expect(bridge.snapshot?['fitnessData'], isA<Map<String, dynamic>>());
      expect(bridge.snapshot?['dayContext'], isA<Map<String, dynamic>>());
      expect(bridge.snapshot?['dailySnapshot'], isA<Map<String, dynamic>>());
    },
  );

  test('exercise timer captures duration and health snapshot', () async {
    final controller = FitnessController(
      store: _MemoryStore(),
      health: _TimerHealthSync(),
    );
    await controller.load();
    final ex = controller.nextWorkout!.exercises.first;

    await controller.startCurrentWorkout();
    await controller.startExerciseTimer(
      exerciseId: ex.exerciseId,
      exerciseName: ex.name,
    );
    expect(controller.isExerciseRunning(ex.exerciseId), isTrue);

    await controller.stopExerciseTimer(ex.exerciseId);
    expect(controller.isExerciseRunning(ex.exerciseId), isFalse);

    // Stopping the single sample exercise auto-closes the workout.
    final timings = controller.data.logs.single.exerciseTimings;
    expect(timings, hasLength(1));
    expect(timings.single.durationSeconds, isNotNull);
    expect(timings.single.durationSeconds, greaterThanOrEqualTo(0));
    expect(timings.single.healthSnapshot?.heartRateBpm, 132);
  });

  test('pause then resume reduces duration by paused window', () async {
    final controller = FitnessController(
      store: _MemoryStore(),
      health: _TimerHealthSync(),
    );
    await controller.load();
    final ex = controller.nextWorkout!.exercises.first;

    await controller.startCurrentWorkout();
    await controller.startExerciseTimer(
      exerciseId: ex.exerciseId,
      exerciseName: ex.name,
    );
    await controller.pauseExerciseTimer(ex.exerciseId);
    expect(controller.isExercisePaused(ex.exerciseId), isTrue);
    await Future<void>.delayed(const Duration(seconds: 1));
    await controller.resumeExerciseTimer(ex.exerciseId);
    expect(controller.isExerciseRunning(ex.exerciseId), isTrue);
    await controller.stopExerciseTimer(ex.exerciseId);

    final t = controller.data.logs.single.exerciseTimings.single;
    expect(t.pausedSeconds, greaterThanOrEqualTo(1));
    // active duration must be <= wall duration
    final wall = t.completedAt!.difference(t.startedAt).inSeconds;
    expect(t.durationSeconds, lessThanOrEqualTo(wall));
    expect(t.durationSeconds, wall - t.pausedSeconds);
  });

  test('stop is terminal — second start is a no-op', () async {
    final controller = FitnessController(
      store: _MemoryStore(),
      health: _TimerHealthSync(),
    );
    await controller.load();
    final ex = controller.nextWorkout!.exercises.first;

    await controller.startCurrentWorkout();
    await controller.startExerciseTimer(
      exerciseId: ex.exerciseId,
      exerciseName: ex.name,
    );
    await controller.stopExerciseTimer(ex.exerciseId);

    // Attempt to restart
    await controller.startExerciseTimer(
      exerciseId: ex.exerciseId,
      exerciseName: ex.name,
    );

    // workout may have auto-closed (single exercise sample data) — look in the log either way
    final log = controller.activeWorkoutLog ?? controller.justCompletedLog!;
    final entries = log.exerciseTimings
        .where((t) => t.exerciseId == ex.exerciseId)
        .toList();
    expect(entries, hasLength(1));
    expect(entries.single.isStopped, isTrue);
  });

  test('stopping the last running exercise auto-closes the workout', () async {
    final controller = FitnessController(
      store: _MemoryStore(),
      health: _TimerHealthSync(),
    );
    await controller.load();
    final exercises = controller.nextWorkout!.exercises;

    await controller.startCurrentWorkout();
    for (final ex in exercises) {
      await controller.startExerciseTimer(
        exerciseId: ex.exerciseId,
        exerciseName: ex.name,
      );
      await controller.stopExerciseTimer(ex.exerciseId);
    }

    expect(controller.activeWorkoutLog, isNull);
    expect(controller.justCompletedLog, isNotNull);
    expect(controller.justCompletedLog!.completedAt, isNotNull);
    expect(
      controller.justCompletedLog!.exerciseTimings.every((t) => t.isStopped),
      isTrue,
    );
  });

  test('stopCurrentWorkout finalises a still-paused exercise', () async {
    final controller = FitnessController(
      store: _MemoryStore(),
      health: _TimerHealthSync(),
    );
    await controller.load();
    final ex = controller.nextWorkout!.exercises.first;

    await controller.startCurrentWorkout();
    await controller.startExerciseTimer(
      exerciseId: ex.exerciseId,
      exerciseName: ex.name,
    );
    await controller.pauseExerciseTimer(ex.exerciseId);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await controller.stopCurrentWorkout();

    final log = controller.data.logs.single;
    final t = log.exerciseTimings.single;
    expect(t.isStopped, isTrue);
    expect(t.pausedAt, isNull);
    expect(controller.justCompletedLog?.id, log.id);
  });

  test(
    'updateCompletedLog persists notes and re-exports day context',
    () async {
      final store = _MemoryStore();
      final controller = FitnessController(
        store: store,
        health: _TimerHealthSync(),
      );
      await controller.load();
      final ex = controller.nextWorkout!.exercises.first;

      await controller.startCurrentWorkout();
      await controller.startExerciseTimer(
        exerciseId: ex.exerciseId,
        exerciseName: ex.name,
      );
      await controller.stopCurrentWorkout();
      final logId = controller.justCompletedLog!.id;

      await controller.updateCompletedLog(
        logId,
        notes: 'Felt strong on bench',
        readiness: 5,
        soreness: 1,
      );

      final stored = controller.data.logs.firstWhere((l) => l.id == logId);
      expect(stored.notes, 'Felt strong on bench');
      expect(stored.readiness, 5);
      expect(stored.soreness, 1);

      final payload = store.jsonFiles['day_context.json']!;
      final logs = payload['trainingLogs'] as List<dynamic>;
      final exported =
          logs.firstWhere(
                (item) => (item as Map<String, dynamic>)['id'] == logId,
              )
              as Map<String, dynamic>;
      expect(exported['notes'], 'Felt strong on bench');
      expect(exported['readiness'], 5);
    },
  );

  test('stopping a workout auto-closes any running exercise timer', () async {
    final controller = FitnessController(
      store: _MemoryStore(),
      health: _TimerHealthSync(),
    );
    await controller.load();
    final ex = controller.nextWorkout!.exercises.first;

    await controller.startCurrentWorkout();
    await controller.startExerciseTimer(
      exerciseId: ex.exerciseId,
      exerciseName: ex.name,
    );
    await controller.stopCurrentWorkout();

    final log = controller.data.logs.single;
    expect(log.completedAt, isNotNull);
    expect(log.totalDurationSeconds, isNotNull);
    expect(log.exerciseTimings.single.isRunning, isFalse);
    expect(log.exerciseTimings.single.completedAt, isNotNull);
  });

  test('workout log JSON round-trips exerciseTimings', () {
    final start = DateTime.utc(2026, 5, 21, 10);
    final end = start.add(const Duration(minutes: 3));
    final log = WorkoutLog(
      id: 'log-1',
      workoutId: 'w-1',
      title: 'Push A',
      startedAt: start,
      completedAt: end.add(const Duration(minutes: 30)),
      readiness: 3,
      soreness: 2,
      notes: '',
      sets: const [],
      healthWriteStatus: 'manual',
      exerciseTimings: [
        ExerciseTiming(
          exerciseId: 'ex-1',
          exerciseName: 'Bench Press',
          startedAt: start,
          completedAt: end,
          healthSnapshot: LiveHealthMetrics(
            updatedAt: end,
            sampleCount: 4,
            heartRateBpm: 138,
          ),
        ),
      ],
    );

    final restored = WorkoutLog.fromJson(log.toJson());
    expect(restored.exerciseTimings, hasLength(1));
    expect(restored.exerciseTimings.single.durationSeconds, 180);
    expect(restored.exerciseTimings.single.healthSnapshot?.heartRateBpm, 138);
    expect(restored.totalDurationSeconds, 33 * 60);
  });

  test('workout completion creates active memory from notes', () async {
    final controller = FitnessController(store: _MemoryStore());
    await controller.load();
    final exercise = controller.nextWorkout!.exercises.first;

    await controller.logSet(exercise, 20, 8, 7);
    await controller.completeCurrentWorkout(
      notes: 'Form cue: ribs down on every rep.',
    );

    expect(
      controller.data.memories.any(
        (item) =>
            item.category == MemoryCategory.form &&
            item.source == 'auto_workout' &&
            item.summary.contains('ribs down') &&
            item.active,
      ),
      isTrue,
    );
  });

  test('watch payload serializes current planned workout', () {
    final service = WatchSyncService();
    final workout = sampleFitnessData().nextWorkout!;
    final payload = service.buildWorkoutPayload(
      workout: workout,
      sentAt: DateTime.utc(2026, 5, 22, 8),
    );

    expect(payload['schemaVersion'], WatchSyncService.schemaVersion);
    expect(payload['sentAt'], '2026-05-22T08:00:00.000Z');
    final workoutJson = payload['workout'] as Map<String, dynamic>;
    expect(workoutJson['id'], workout.id);
    expect(workoutJson['exercises'], isNotEmpty);
  });

  test('watch payload includes completed log when workout is already done', () {
    final service = WatchSyncService();
    final data = sampleFitnessData();
    final workout = data.nextWorkout!;
    final completed = WorkoutLog(
      id: 'log_done',
      workoutId: workout.id,
      title: workout.title,
      startedAt: DateTime.utc(2026, 5, 23, 8),
      completedAt: DateTime.utc(2026, 5, 23, 9),
      readiness: 3,
      soreness: 2,
      notes: '',
      sets: const [],
      healthWriteStatus: 'watch_health_synced',
      healthMetrics: LiveHealthMetrics(
        updatedAt: DateTime.utc(2026, 5, 23, 9),
        sampleCount: 12,
        heartRateBpm: 121,
        activeEnergyKcal: 245,
      ),
    );

    final payload = service.buildWorkoutPayload(
      workout: workout,
      completedLog: completed,
      sentAt: DateTime.utc(2026, 5, 23, 9, 1),
    );

    final completedJson = payload['completedLog'] as Map<String, dynamic>;
    expect(completedJson['workoutId'], workout.id);
    expect(completedJson['completedAt'], '2026-05-23T09:00:00.000Z');
    expect(completedJson['totalDurationSeconds'], 3600);
    expect(
      (completedJson['healthMetrics']
          as Map<String, dynamic>)['activeEnergyKcal'],
      245,
    );
  });

  test('iPhone completion syncs completed workout to watch', () async {
    final watch = _FakeWatchSync();
    final controller = FitnessController(
      store: _MemoryStore(),
      health: _TimerHealthSync(),
      watchSync: watch,
    );
    await controller.load();
    final workout = controller.nextWorkout!;
    final exercise = workout.exercises.first;

    await controller.logSet(exercise, 20, 8, 6);
    await controller.completeCurrentWorkout();
    await Future<void>.delayed(Duration.zero);

    expect(controller.nextWorkout?.id, isNot(workout.id));
    final payload = watch.sentPayloads.last;
    expect((payload['workout'] as Map<String, dynamic>)['id'], workout.id);
    expect(payload, isNot(contains('activeLog')));
    final completedJson = payload['completedLog'] as Map<String, dynamic>;
    expect(completedJson['workoutId'], workout.id);
    expect(completedJson['completedAt'], isNotNull);
  });

  test('imports completed watch workout into logs', () async {
    final watch = _FakeWatchSync();
    final controller = FitnessController(
      store: _MemoryStore(),
      watchSync: watch,
    );
    await controller.load();
    final workout = controller.nextWorkout!;
    final exercise = workout.exercises.first;

    await controller.handleWatchWorkoutCompleted(
      _watchCompletionPayload(workout, exercise, setCount: 2),
    );

    final log = controller.data.logs.single;
    expect(log.workoutId, workout.id);
    expect(log.completedAt, isNotNull);
    expect(log.sets, hasLength(2));
    expect(log.healthWriteStatus, 'watch_health_denied');
    expect(log.healthMetrics?.sampleCount, 0);
    expect(log.healthMetrics?.hasAnyValue, isFalse);
  });

  test(
    'watch duplicate completion is ignored unless it has more sets',
    () async {
      final controller = FitnessController(
        store: _MemoryStore(),
        watchSync: _FakeWatchSync(),
      );
      await controller.load();
      final workout = controller.nextWorkout!;
      final exercise = workout.exercises.first;

      await controller.handleWatchWorkoutCompleted(
        _watchCompletionPayload(workout, exercise, setCount: 2),
      );
      await controller.handleWatchWorkoutCompleted(
        _watchCompletionPayload(workout, exercise, setCount: 1),
      );
      expect(controller.data.logs.single.sets, hasLength(2));

      await controller.handleWatchWorkoutCompleted(
        _watchCompletionPayload(workout, exercise, setCount: 3),
      );
      expect(controller.data.logs.single.sets, hasLength(3));
    },
  );

  test(
    'phone defers HealthKit write and ends watch session when watch is active',
    () async {
      final watch = _FakeWatchSync();
      final health = _MatchingHealthSync();
      final controller = FitnessController(
        store: _MemoryStore(),
        health: health,
        watchSync: watch,
      );
      await controller.load();
      final workout = controller.nextWorkout!;
      final exercise = workout.exercises.first;

      watch.eventsController.add({
        'type': 'watchSessionActive',
        'workoutId': workout.id,
      });
      await Future<void>.delayed(Duration.zero);
      expect(controller.debugActiveWatchSessionWorkoutId, workout.id);

      await controller.logSet(exercise, 20, 8, 6);
      await controller.completeCurrentWorkout();

      expect(watch.endedWorkoutIds, [workout.id]);
      expect(health.writeCount, 0);
      expect(
        controller.data.logs.single.healthWriteStatus,
        'pending_watch_completion',
      );
    },
  );

  test('watch completion merges over active iPhone workout', () async {
    final controller = FitnessController(
      store: _MemoryStore(),
      health: _TimerHealthSync(),
      watchSync: _FakeWatchSync(),
    );
    await controller.load();
    final workout = controller.nextWorkout!;
    final exercise = workout.exercises.first;

    await controller.startCurrentWorkout();
    expect(controller.activeWorkoutLog, isNotNull);

    await controller.handleWatchWorkoutCompleted(
      _watchCompletionPayload(workout, exercise, setCount: 2),
    );

    expect(controller.activeWorkoutLog, isNull);
    expect(controller.justCompletedLog?.sets, hasLength(2));
    expect(controller.data.logs, hasLength(1));
  });
}

class _MemoryStore extends LocalFitnessStore {
  FitnessData? saved;
  LocalBridgeConfig bridgeConfig = const LocalBridgeConfig();
  final jsonFiles = <String, Map<String, dynamic>>{};

  @override
  Future<FitnessData> load() async => saved ?? sampleFitnessData();

  @override
  Future<void> save(FitnessData data) async {
    saved = data;
  }

  @override
  Future<LocalBridgeConfig> loadBridgeConfig() async => bridgeConfig;

  @override
  Future<void> saveBridgeConfig(LocalBridgeConfig config) async {
    bridgeConfig = config;
  }

  @override
  Future<File> writeExchangeJson(
    String fileName,
    Map<String, dynamic> payload,
  ) async {
    jsonFiles[fileName] = payload;
    return File(fileName);
  }

  @override
  Future<Map<String, dynamic>?> readExchangeJson(String fileName) async {
    return jsonFiles[fileName];
  }

  @override
  Future<bool> exchangeJsonExists(String fileName) async {
    return jsonFiles.containsKey(fileName);
  }

  @override
  Future<void> deleteExchangeJson(String fileName) async {
    jsonFiles.remove(fileName);
  }
}

class _CapturingBridgeService extends LocalBridgeService {
  Map<String, dynamic>? snapshot;

  @override
  Future<void> uploadAppSnapshot(
    LocalBridgeConfig config,
    Map<String, dynamic> payload,
  ) async {
    snapshot = payload;
  }
}

class _FakeWatchSync extends WatchSyncService {
  final sentPayloads = <Map<String, dynamic>>[];
  final endedWorkoutIds = <String>[];
  final eventsController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => eventsController.stream;

  @override
  Future<String> syncWorkout({
    required PlannedWorkout workout,
    WorkoutLog? activeLog,
    WorkoutLog? completedLog,
  }) async {
    sentPayloads.add(
      buildWorkoutPayload(
        workout: workout,
        activeLog: activeLog,
        completedLog: completedLog,
      ),
    );
    return 'Apple Watch workout synced';
  }

  @override
  Future<void> markCompletionHandled(String completionId) async {}

  @override
  Future<void> endWatchWorkout(String workoutId) async {
    endedWorkoutIds.add(workoutId);
  }
}

Map<String, dynamic> _watchCompletionPayload(
  PlannedWorkout workout,
  ExercisePrescription exercise, {
  required int setCount,
}) {
  final started = DateTime.utc(2026, 5, 22, 8);
  final completed = started.add(const Duration(minutes: 45));
  return {
    'schemaVersion': WatchSyncService.schemaVersion,
    'completionId': 'completion-$setCount',
    'workoutId': workout.id,
    'title': workout.title,
    'startedAt': started.toIso8601String(),
    'completedAt': completed.toIso8601String(),
    'pausedSeconds': 30,
    'healthWriteStatus': 'watch_health_denied',
    'healthMetrics': {
      'updatedAt': completed.toIso8601String(),
      'sampleCount': 0,
    },
    'sets': List.generate(
      setCount,
      (index) => {
        'exerciseId': exercise.exerciseId,
        'exerciseName': exercise.name,
        'setNumber': index + 1,
        'weightKg': 20,
        'reps': 8 + index,
        'rpe': 7,
      },
    ),
    'exerciseTimings': [
      {
        'exerciseId': exercise.exerciseId,
        'exerciseName': exercise.name,
        'startedAt': started.toIso8601String(),
        'completedAt': completed.toIso8601String(),
        'pausedSeconds': 30,
      },
    ],
  };
}

class _MatchingHealthSync extends HealthSyncService {
  var writeCount = 0;

  @override
  Future<HealthWorkoutMatch?> readCompletedWorkoutMatch(WorkoutLog log) async {
    return HealthWorkoutMatch(
      status: 'matched_apple_health_workout:FUNCTIONAL',
      metrics: LiveHealthMetrics(
        updatedAt: DateTime(2026, 5, 19, 12),
        sampleCount: 12,
        heartRateBpm: 124,
        steps: 180,
        activeEnergyKcal: 96,
      ),
    );
  }

  @override
  Future<String> writeWorkout(WorkoutLog log) async {
    writeCount += 1;
    return 'written_to_apple_health';
  }
}

class _NutritionHealthSync extends HealthSyncService {
  var nutritionWriteCount = 0;

  @override
  Future<String> writeNutrition(NutritionLog log) async {
    nutritionWriteCount += 1;
    return 'nutrition_written_to_apple_health';
  }
}

class _TimerHealthSync extends HealthSyncService {
  @override
  Future<bool> requestLiveWorkoutPermissions() async => true;

  @override
  Future<LiveHealthMetrics> readLiveWorkoutMetrics(DateTime startedAt) async {
    return LiveHealthMetrics(
      updatedAt: DateTime.now(),
      sampleCount: 3,
      heartRateBpm: 132,
      activeEnergyKcal: 18,
    );
  }

  @override
  Future<HealthWorkoutMatch?> readCompletedWorkoutMatch(WorkoutLog log) async =>
      null;

  @override
  Future<String> writeWorkout(WorkoutLog log) async =>
      'written_to_apple_health';

  @override
  Future<DayActivityReport> readDayActivityReport(DateTime day) async {
    return DayActivityReport(
      summary: const DayActivitySummary(
        readStatus: 'ok',
        missingPermissions: [],
        sampleCount: 0,
      ),
      sessions: const [],
    );
  }
}

class _DayContextHealthSync extends HealthSyncService {
  @override
  Future<HealthWorkoutMatch?> readCompletedWorkoutMatch(WorkoutLog log) async {
    return null;
  }

  @override
  Future<String> writeWorkout(WorkoutLog log) async {
    return 'written_to_apple_health';
  }

  @override
  Future<DayActivityReport> readDayActivityReport(DateTime day) async {
    return DayActivityReport(
      summary: const DayActivitySummary(
        readStatus: 'ok',
        missingPermissions: [],
        sampleCount: 2,
        steps: 12000,
        activeEnergyKcal: 700,
      ),
      sessions: [
        DayActivitySession(
          id: 'run-after-training',
          activityType: 'RUNNING',
          startedAt: DateTime(2026, 5, 20, 17),
          endedAt: DateTime(2026, 5, 20, 17, 30),
          distanceMeters: 5000,
          activeEnergyKcal: 310,
        ),
      ],
    );
  }
}
