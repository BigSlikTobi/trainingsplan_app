import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/data/local_store.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/health_sync_service.dart';
import 'package:trainingsplan_app/src/state/fitness_controller.dart';

void main() {
  test('logSet clamps RPE to the valid coaching scale', () async {
    final controller = FitnessController(store: _MemoryStore());
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

  test('workout completion creates active memory from notes', () async {
    final controller = FitnessController(store: _MemoryStore());
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
}

class _MemoryStore extends LocalFitnessStore {
  FitnessData? saved;
  final jsonFiles = <String, Map<String, dynamic>>{};

  @override
  Future<void> save(FitnessData data) async {
    saved = data;
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
