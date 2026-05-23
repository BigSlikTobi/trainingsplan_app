import 'dart:io';

import 'package:path/path.dart' as p;

import '../data/local_store.dart';
import '../models/fitness_models.dart';

class CoachExchangeService {
  CoachExchangeService(this._store);

  final LocalFitnessStore _store;
  static const _trainingBlockPlanFile = 'training_block_plan.json';
  static const _nutritionRequestFile = 'nutrition_analysis_request.json';
  static const _nutritionResultFile = 'nutrition_analysis_result.json';
  static const _dayContextFile = 'day_context.json';
  static const _fuelGuidanceFile = 'fuel_guidance.json';
  static const _memoryWikiFiles = [
    _dayContextFile,
    'daily_snapshot.json',
    _nutritionRequestFile,
  ];

  Future<String> exportDailySnapshot(FitnessData data) async {
    final recentLogs = [...data.logs]..sort(_compareWorkoutLogsNewestFirst);
    final recentNutrition = [...data.nutrition]
      ..sort((a, b) => b.date.compareTo(a.date));
    final latestLog = recentLogs.isEmpty ? null : recentLogs.first;
    final latestNutrition = recentNutrition.isEmpty
        ? null
        : recentNutrition.first;
    final payload = {
      'schema': 'daily_snapshot.v1',
      'createdAt': DateTime.now().toIso8601String(),
      'profile': data.profile.toJson(),
      'activeBlock': data.activeBlock?.toJson(),
      'nextWorkout': data.nextWorkout?.toJson(),
      'latestWorkoutLog': latestLog?.toJson(),
      'latestNutrition': latestNutrition?.toJson(),
      'recentLogs': recentLogs.take(10).map((item) => item.toJson()).toList(),
      'memoryWiki': _memoryWiki(data.memories),
      'coachQuestions': [
        'Should tomorrow be progressed, held, deloaded, or substituted?',
        'Which exercise cues matter most from recent performance?',
        'Do nutrition or readiness signals require training changes?',
      ],
    };
    final file = await _store.writeExchangeJson('daily_snapshot.json', payload);
    return file.path;
  }

  Future<String> exportDayContext({
    required FitnessData data,
    required DayActivityReport activityReport,
    DateTime? day,
  }) async {
    final targetDay = day ?? DateTime.now();
    final windowStart = DateTime(
      targetDay.year,
      targetDay.month,
      targetDay.day,
    );
    final windowEnd = windowStart.add(const Duration(days: 1));
    final trainingLogs = _logsForWindow(data.logs, windowStart, windowEnd)
      ..sort(_compareWorkoutLogsNewestFirst);
    final nutritionLogs = _nutritionForDay(data.nutrition, windowStart)
      ..sort((a, b) => b.date.compareTo(a.date));
    final latestWorkout = trainingLogs.isEmpty ? null : trainingLogs.first;
    final latestNutrition = nutritionLogs.isEmpty ? null : nutritionLogs.first;
    final offset = windowStart.timeZoneOffset;
    final payload = {
      'schema': 'day_context.v1',
      'dayKey': dateKey(windowStart),
      'timezoneOffset': _formatOffset(offset),
      'windowStart': windowStart.toIso8601String(),
      'windowEnd': windowEnd.toIso8601String(),
      'generatedAt': DateTime.now().toIso8601String(),
      'activitySummary': activityReport.summary.toJson(),
      'activitySessions': activityReport.sessions
          .map((item) => item.toJson())
          .toList(),
      'trainingLogs': trainingLogs.map((item) => item.toJson()).toList(),
      'nutritionLogs': nutritionLogs.map((item) => item.toJson()).toList(),
      'latestWorkoutLog': latestWorkout?.toJson(),
      'latestNutrition': latestNutrition?.toJson(),
      'profile': data.profile.toJson(),
      'activeBlock': data.activeBlock?.toJson(),
      'nextWorkout': data.nextWorkout?.toJson(),
      'memoryWiki': _memoryWiki(data.memories),
      'instructions': [
        'This is the primary Codex coaching context for the local calendar day.',
        'Keep training logs, nutrition logs, and Apple Fitness activity separate, but consider them together when adapting coaching.',
        'Post-training walks, runs, rides, and other Apple Health workouts can affect recovery, next-workout intensity, and nutrition needs.',
      ],
    };
    final file = await _store.writeExchangeJson(_dayContextFile, payload);
    return file.path;
  }

  Future<(MealAnalysisRequest, String)> exportNutritionAnalysisRequest({
    required FitnessData data,
    required String description,
    String? imagePath,
  }) async {
    final request = MealAnalysisRequest(
      id: newId('meal_request'),
      createdAt: DateTime.now(),
      description: description.trim(),
      imagePath: await _copyMealImage(imagePath),
      status: 'pending',
    );
    final recentLogs = [...data.logs]..sort(_compareWorkoutLogsNewestFirst);
    final recentNutrition = [...data.nutrition]
      ..sort((a, b) => b.date.compareTo(a.date));
    final latestLog = recentLogs.isEmpty ? null : recentLogs.first;
    final latestNutrition = recentNutrition.isEmpty
        ? null
        : recentNutrition.first;
    final payload = {
      'schema': 'nutrition_analysis_request.v1',
      'createdAt': request.createdAt.toIso8601String(),
      'request': request.toJson(),
      'dayContextFile': _dayContextFile,
      'profile': data.profile.toJson(),
      'currentBodyMetrics': {
        'heightCm': data.profile.heightCm,
        'weightKg': data.profile.weightKg,
        'age': data.profile.age,
        'sex': data.profile.sex,
      },
      'activeBlock': data.activeBlock?.toJson(),
      'nextWorkout': data.nextWorkout?.toJson(),
      'latestWorkoutLog': latestLog?.toJson(),
      'latestNutrition': latestNutrition?.toJson(),
      'recentLogs': recentLogs.take(10).map((item) => item.toJson()).toList(),
      'recentNutrition': recentNutrition
          .take(10)
          .map((item) => item.toJson())
          .toList(),
      'memoryWiki': _memoryWiki(
        data.memories.where(_isNutritionRelevantMemory),
      ),
      'instructions': [
        'Analyze the meal from description and optional imagePath.',
        'Estimate calories, protein, carbs, and fat as integers.',
        'Infer the daily calorie target from user goal, training status, recent calorie intake, bodyweight trend, height, weight, age, sex, training days, and session minutes.',
        'Return nutrition_analysis_result.json with schema nutrition_analysis_result.v1.',
        'Include assumptions and confidence because image and text meal estimates are approximate.',
      ],
      'expectedResultShape': {
        'schema': 'nutrition_analysis_result.v1',
        'requestId': request.id,
        'mealDescription': 'short description of inferred meal',
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'bodyWeightKg': data.profile.weightKg,
        'confidence': 0.0,
        'assumptions': <String>[],
        'rationale': 'why these estimates and target fit the context',
        'correctionNotes': 'what user should correct if the estimate is off',
        'target': data.profile.nutritionTarget.toJson(),
      },
    };
    final file = await _store.writeExchangeJson(_nutritionRequestFile, payload);
    return (request, file.path);
  }

  Future<TrainingBlock?> readTrainingBlockPlan() async {
    final json = await _store.readExchangeJson(_trainingBlockPlanFile);
    if (json == null) return null;
    final blockJson = (json['block'] as Map?)?.cast<String, dynamic>() ?? json;
    final block = TrainingBlock.fromJson(blockJson);
    if (block.workouts.isEmpty || block.durationWeeks < 1) {
      throw const FormatException('training_block_plan.json has no workouts.');
    }
    return block.copyWith(createdBy: 'Codex import');
  }

  Future<bool> hasTrainingBlockPlan() {
    return _store.exchangeJsonExists(_trainingBlockPlanFile);
  }

  Future<void> clearTrainingBlockPlan() {
    return _store.deleteExchangeJson(_trainingBlockPlanFile);
  }

  Future<PlannedWorkout?> readNextDayPlan() async {
    final json = await _store.readExchangeJson('next_day_plan.json');
    if (json == null) return null;
    final workoutJson =
        (json['workout'] as Map?)?.cast<String, dynamic>() ?? json;
    final workout = PlannedWorkout.fromJson(workoutJson);
    if (workout.exercises.isEmpty) {
      throw const FormatException('next_day_plan.json has no exercises.');
    }
    return workout;
  }

  Future<bool> hasNutritionAnalysisResult() {
    return _store.exchangeJsonExists(_nutritionResultFile);
  }

  Future<MealAnalysisResult?> readNutritionAnalysisResult() async {
    final json = await _store.readExchangeJson(_nutritionResultFile);
    if (json == null) return null;
    final resultJson =
        (json['result'] as Map?)?.cast<String, dynamic>() ?? json;
    final result = MealAnalysisResult.fromJson(resultJson);
    if (result.calories <= 0) {
      throw const FormatException(
        'nutrition_analysis_result.json must include positive calories.',
      );
    }
    if (result.protein < 0 || result.carbs < 0 || result.fat < 0) {
      throw const FormatException(
        'nutrition_analysis_result.json macros cannot be negative.',
      );
    }
    return result;
  }

  Future<void> clearNutritionAnalysisResult() {
    return _store.deleteExchangeJson(_nutritionResultFile);
  }

  Future<void> clearNutritionAnalysisRequest() {
    return _store.deleteExchangeJson(_nutritionRequestFile);
  }

  Future<FuelGuidance?> readFuelGuidance() async {
    final json = await _store.readExchangeJson(_fuelGuidanceFile);
    if (json == null) return null;
    return FuelGuidance.fromJson(json);
  }

  Future<bool> hasFuelGuidance() {
    return _store.exchangeJsonExists(_fuelGuidanceFile);
  }

  Future<void> clearFuelGuidance() {
    return _store.deleteExchangeJson(_fuelGuidanceFile);
  }

  Future<List<MemoryEntry>> readExchangeMemoryWikiEntries() async {
    final entries = <MemoryEntry>[];
    for (final fileName in _memoryWikiFiles) {
      final json = await _store.readExchangeJson(fileName);
      final wiki = (json?['memoryWiki'] as Map?)?.cast<String, dynamic>();
      final rawEntries = wiki?['entries'];
      if (rawEntries is! List) continue;
      for (final raw in rawEntries) {
        if (raw is! Map) continue;
        final entry = MemoryEntry.fromJson(raw.cast<String, dynamic>());
        if (entry.title.trim().isEmpty || entry.summary.trim().isEmpty) {
          continue;
        }
        entries.add(entry);
      }
    }
    return entries;
  }

  Future<String?> _copyMealImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    final source = File(imagePath.trim());
    if (!source.existsSync()) return imagePath.trim();

    final dir = await _store.getExchangeDirectory();
    final imagesDir = Directory(p.join(dir.path, 'meal_images'));
    if (!imagesDir.existsSync()) await imagesDir.create(recursive: true);
    final extension = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path);
    final target = File(
      p.join(imagesDir.path, '${newId('meal_image')}$extension'),
    );
    await source.copy(target.path);
    return target.path;
  }
}

int _compareWorkoutLogsNewestFirst(WorkoutLog a, WorkoutLog b) {
  final aTime = a.completedAt ?? a.startedAt;
  final bTime = b.completedAt ?? b.startedAt;
  return bTime.compareTo(aTime);
}

List<WorkoutLog> _logsForWindow(
  List<WorkoutLog> logs,
  DateTime windowStart,
  DateTime windowEnd,
) {
  return logs.where((log) {
    final start = log.startedAt;
    final end = log.completedAt ?? log.startedAt;
    return start.isBefore(windowEnd) && end.isAfter(windowStart);
  }).toList();
}

List<NutritionLog> _nutritionForDay(List<NutritionLog> logs, DateTime day) {
  final key = dateKey(day);
  return logs.where((log) => dateKey(log.date) == key).toList();
}

String _formatOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final absolute = offset.abs();
  final hours = absolute.inHours.toString().padLeft(2, '0');
  final minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '$sign$hours:$minutes';
}

Map<String, dynamic> _memoryWiki(Iterable<MemoryEntry> memories) {
  final active = memories.where((item) => item.active).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  final byCategory = <String, List<Map<String, dynamic>>>{};
  for (final memory in active.take(30)) {
    byCategory
        .putIfAbsent(memory.category.name, () => [])
        .add(memory.toPromptJson());
  }
  return {
    'schema': 'memory_wiki.v1',
    'entryCount': active.length,
    'entries': active.take(30).map((item) => item.toPromptJson()).toList(),
    'byCategory': byCategory,
    'instructions':
        'Use these active memories as durable coaching context. Prefer recent, high-confidence entries, and do not treat inactive or missing memories as facts.',
  };
}

bool _isNutritionRelevantMemory(MemoryEntry memory) {
  return switch (memory.category) {
    MemoryCategory.nutrition ||
    MemoryCategory.recovery ||
    MemoryCategory.preference ||
    MemoryCategory.constraint ||
    MemoryCategory.goal => true,
    MemoryCategory.training || MemoryCategory.form => false,
  };
}
