import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/data/local_store.dart';
import 'package:trainingsplan_app/src/data/seed_data.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/coach_exchange_service.dart';

void main() {
  test('daily snapshot exports latest workout log with logged sets', () async {
    final store = _CapturingStore();
    final service = CoachExchangeService(store);
    final data = createSeedFitnessData();
    final workout = data.nextWorkout!;
    final olderLog = WorkoutLog(
      id: 'older-log',
      workoutId: 'older-workout',
      title: 'Older workout',
      startedAt: DateTime(2026, 5, 19, 10),
      completedAt: DateTime(2026, 5, 19, 10, 30),
      readiness: 3,
      soreness: 2,
      notes: '',
      sets: const [],
      healthWriteStatus: 'not_synced',
    );
    final latestLog = WorkoutLog(
      id: 'latest-log',
      workoutId: workout.id,
      title: workout.title,
      startedAt: DateTime(2026, 5, 19, 11),
      completedAt: DateTime(2026, 5, 19, 11, 45),
      readiness: 3,
      soreness: 2,
      notes: 'sprinting might be too early',
      sets: const [
        LoggedSet(
          exerciseId: 'goblet_squat',
          exerciseName: 'Goblet Squat',
          setNumber: 1,
          weightKg: 20,
          reps: 12,
          rpe: 6,
        ),
      ],
      healthWriteStatus: 'not_synced',
    );

    await service.exportDailySnapshot(
      data.copyWith(logs: [latestLog, olderLog]),
    );

    final latestWorkoutLog =
        store.payload['latestWorkoutLog'] as Map<String, dynamic>;
    final recentLogs = store.payload['recentLogs'] as List<dynamic>;
    final sets = latestWorkoutLog['sets'] as List<dynamic>;

    expect(latestWorkoutLog['id'], 'latest-log');
    expect(latestWorkoutLog['notes'], 'sprinting might be too early');
    expect(sets, hasLength(1));
    expect(
      (sets.single as Map<String, dynamic>)['exerciseName'],
      'Goblet Squat',
    );
    expect(recentLogs.first, containsPair('id', 'latest-log'));
    final memoryWiki = store.payload['memoryWiki'] as Map<String, dynamic>;
    expect(memoryWiki['schema'], 'memory_wiki.v1');
    expect(memoryWiki['entries'], isA<List<dynamic>>());
  });

  test(
    'nutrition analysis request exports profile training and recent intake',
    () async {
      final store = _CapturingStore();
      final service = CoachExchangeService(store);

      final (request, path) = await service.exportNutritionAnalysisRequest(
        data: createSeedFitnessData(),
        description: 'Chicken rice bowl with avocado',
      );

      expect(path, 'nutrition_analysis_request.json');
      expect(request.description, 'Chicken rice bowl with avocado');
      expect(store.fileName, 'nutrition_analysis_request.json');
      expect(store.payload['schema'], 'nutrition_analysis_request.v1');
      expect(store.payload['profile'], isA<Map<String, dynamic>>());
      expect(store.payload['activeBlock'], isA<Map<String, dynamic>>());
      expect(store.payload['nextWorkout'], isA<Map<String, dynamic>>());
      expect(store.payload['dayContextFile'], 'day_context.json');
      expect(store.payload['latestWorkoutLog'], isNull);
      expect(store.payload['latestNutrition'], isA<Map<String, dynamic>>());
      expect(store.payload['recentNutrition'], isA<List<dynamic>>());
      expect(store.payload['memoryWiki'], isA<Map<String, dynamic>>());
    },
  );

  test('day context exports local-day activity, sessions, and logs', () async {
    final store = _CapturingStore();
    final service = CoachExchangeService(store);
    final data = createSeedFitnessData();
    final workout = data.nextWorkout!;
    final todayLog = WorkoutLog(
      id: 'today-log',
      workoutId: workout.id,
      title: workout.title,
      startedAt: DateTime(2026, 5, 20, 9),
      completedAt: DateTime(2026, 5, 20, 10),
      readiness: 4,
      soreness: 3,
      notes: 'Good session',
      sets: const [],
      healthWriteStatus: 'matched_apple_health_workout:FUNCTIONAL',
    );
    final olderLog = WorkoutLog(
      id: 'older-log',
      workoutId: 'older',
      title: 'Older',
      startedAt: DateTime(2026, 5, 19, 9),
      completedAt: DateTime(2026, 5, 19, 10),
      readiness: 3,
      soreness: 2,
      notes: '',
      sets: const [],
      healthWriteStatus: 'not_synced',
    );
    final activity = DayActivityReport(
      summary: const DayActivitySummary(
        readStatus: 'ok',
        missingPermissions: [],
        sampleCount: 4,
        steps: 8200,
        activeEnergyKcal: 640,
      ),
      sessions: [
        DayActivitySession(
          id: 'bike-ride',
          activityType: 'BIKING',
          startedAt: DateTime(2026, 5, 20, 18),
          endedAt: DateTime(2026, 5, 20, 18, 25),
          distanceMeters: 6200,
          activeEnergyKcal: 180,
        ),
      ],
    );

    await service.exportDayContext(
      data: data.copyWith(logs: [olderLog, todayLog]),
      activityReport: activity,
      day: DateTime(2026, 5, 20, 12),
    );

    expect(store.fileName, 'day_context.json');
    expect(store.payload['schema'], 'day_context.v1');
    expect(store.payload['dayKey'], '2026-05-20');
    expect(store.payload['windowStart'], '2026-05-20T00:00:00.000');
    final summary = store.payload['activitySummary'] as Map<String, dynamic>;
    expect(summary['steps'], 8200);
    final sessions = store.payload['activitySessions'] as List<dynamic>;
    expect(sessions.single, containsPair('activityType', 'BIKING'));
    final trainingLogs = store.payload['trainingLogs'] as List<dynamic>;
    expect(trainingLogs, hasLength(1));
    expect(
      trainingLogs.single as Map<String, dynamic>,
      containsPair('id', 'today-log'),
    );
    final latestWorkoutLog =
        store.payload['latestWorkoutLog'] as Map<String, dynamic>;
    expect(latestWorkoutLog['id'], 'today-log');
  });

  test('daily snapshot exports active memory wiki entries', () async {
    final store = _CapturingStore();
    final service = CoachExchangeService(store);
    final data = createSeedFitnessData().copyWith(
      memories: [
        MemoryEntry(
          id: 'active-memory',
          createdAt: DateTime(2026, 5, 20, 9),
          updatedAt: DateTime(2026, 5, 20, 9),
          category: MemoryCategory.form,
          title: 'Squat cue',
          summary: 'Keep heel pressure.',
          markdown: '',
          source: 'manual',
          confidence: .9,
          active: true,
        ),
        MemoryEntry(
          id: 'inactive-memory',
          createdAt: DateTime(2026, 5, 20, 8),
          updatedAt: DateTime(2026, 5, 20, 8),
          category: MemoryCategory.training,
          title: 'Paused',
          summary: 'Do not export.',
          markdown: '',
          source: 'manual',
          confidence: .4,
          active: false,
        ),
      ],
    );

    await service.exportDailySnapshot(data);

    final memoryWiki = store.payload['memoryWiki'] as Map<String, dynamic>;
    final entries = memoryWiki['entries'] as List<dynamic>;

    expect(memoryWiki['entryCount'], 1);
    expect(entries.single, containsPair('title', 'Squat cue'));
  });

  test('nutrition request exports only nutrition-relevant memories', () async {
    final store = _CapturingStore();
    final service = CoachExchangeService(store);
    final now = DateTime(2026, 5, 20, 9);
    final data = createSeedFitnessData().copyWith(
      memories: [
        MemoryEntry(
          id: 'nutrition-memory',
          createdAt: now,
          updatedAt: now,
          category: MemoryCategory.nutrition,
          title: 'Lunch pattern',
          summary: 'Protein bowl works well.',
          markdown: '',
          source: 'manual',
          confidence: .8,
          active: true,
        ),
        MemoryEntry(
          id: 'form-memory',
          createdAt: now,
          updatedAt: now,
          category: MemoryCategory.form,
          title: 'Squat cue',
          summary: 'Keep heel pressure.',
          markdown: '',
          source: 'manual',
          confidence: .9,
          active: true,
        ),
      ],
    );

    await service.exportNutritionAnalysisRequest(
      data: data,
      description: 'Chicken rice bowl',
    );

    final memoryWiki = store.payload['memoryWiki'] as Map<String, dynamic>;
    final entries = memoryWiki['entries'] as List<dynamic>;

    expect(entries.single, containsPair('title', 'Lunch pattern'));
  });

  test('nutrition analysis result validates positive calories', () async {
    final store = _CapturingStore()
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
        },
      };
    final service = CoachExchangeService(store);

    final result = await service.readNutritionAnalysisResult();

    expect(result?.calories, 780);
    expect(result?.protein, 48);
  });
}

class _CapturingStore extends LocalFitnessStore {
  Map<String, dynamic> payload = const {};
  String fileName = '';
  final jsonFiles = <String, Map<String, dynamic>>{};

  @override
  Future<File> writeExchangeJson(
    String fileName,
    Map<String, dynamic> payload,
  ) async {
    this.fileName = fileName;
    this.payload = payload;
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
