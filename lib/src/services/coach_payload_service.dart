import '../models/fitness_models.dart';

class CoachPayloadService {
  Map<String, dynamic> buildDailySnapshot(FitnessData data) {
    final recentLogs = [...data.logs]..sort(_compareWorkoutLogsNewestFirst);
    final recentNutrition = [...data.nutrition]
      ..sort((a, b) => b.date.compareTo(a.date));
    final latestLog = recentLogs.isEmpty ? null : recentLogs.first;
    final latestNutrition = recentNutrition.isEmpty
        ? null
        : recentNutrition.first;
    return {
      'schema': 'daily_snapshot.v1',
      'createdAt': DateTime.now().toIso8601String(),
      'profile': data.profile.toJson(),
      'activeBlock': data.activeBlock?.toJson(),
      'nextWorkout': data.nextWorkout?.toJson(),
      'latestWorkoutLog': latestLog?.toJson(),
      'latestNutrition': latestNutrition?.toJson(),
      'recentLogs': recentLogs.take(10).map((item) => item.toJson()).toList(),
      'memoryWiki': _memoryWiki(data.memories),
      'personalRecords': _activeRecords(data.personalRecords),
      if (data.latestFuelCheckIn != null)
        'latestFuelCheckIn': data.latestFuelCheckIn!.toJson(),
      if (data.fuelDiary.isNotEmpty)
        'fuelDiary': data.fuelDiary.map((e) => e.toJson()).toList(),
      'coachQuestions': [
        'Should tomorrow be progressed, held, deloaded, or substituted?',
        'Which exercise cues matter most from recent performance?',
        'Do nutrition or readiness signals require training changes?',
      ],
    };
  }

  Map<String, dynamic> buildDayContext({
    required FitnessData data,
    required DayActivityReport activityReport,
    DateTime? day,
  }) {
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
    return {
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
      'personalRecords': _activeRecords(data.personalRecords),
      if (data.latestFuelCheckIn != null)
        'latestFuelCheckIn': data.latestFuelCheckIn!.toJson(),
      if (data.fuelDiary.isNotEmpty)
        'fuelDiary': data.fuelDiary.map((e) => e.toJson()).toList(),
      'instructions': [
        'This is the primary T4L Gym Bro coaching context for the local calendar day.',
        'Keep training logs, nutrition logs, and Apple Fitness activity separate, but consider them together when adapting coaching.',
        'Post-training walks, runs, rides, and other Apple Health workouts can affect recovery, next-workout intensity, and nutrition needs.',
      ],
    };
  }

  (MealAnalysisRequest, Map<String, dynamic>) buildNutritionAnalysisRequest({
    required FitnessData data,
    required String description,
    String? imagePath,
  }) {
    final request = MealAnalysisRequest(
      id: newId('meal_request'),
      createdAt: DateTime.now(),
      description: description.trim(),
      imagePath: imagePath,
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
      'dayContextKind': 'day_context',
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
        'Return a nutrition_analysis_result.v1 payload.',
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
    return (request, payload);
  }

  TrainingBlock parseTrainingBlockPlan(Map<String, dynamic> json) {
    final blockJson = (json['block'] as Map?)?.cast<String, dynamic>() ?? json;
    final block = TrainingBlock.fromJson(blockJson);
    if (block.workouts.isEmpty || block.durationWeeks < 1) {
      throw const FormatException('Training block plan has no workouts.');
    }
    return block.copyWith(createdBy: 'T4L Gym Bro import');
  }

  PlannedWorkout parseNextDayPlan(Map<String, dynamic> json) {
    final workoutJson = _workoutPayloadObject(json);
    final workout = PlannedWorkout.fromJson(workoutJson);
    if (workout.exercises.isEmpty) {
      throw const FormatException('Next-day plan has no exercises.');
    }
    return workout;
  }

  ({
    PlannedWorkout workout,
    String? dailyMotto,
    YesterdaySummary? yesterdaySummary,
    CoachingGoals? goals,
  })
  parseNextDayPlanWithContext(Map<String, dynamic> json) {
    final workout = parseNextDayPlan(json);
    return (
      workout: workout,
      dailyMotto: json['dailyMotto'] as String?,
      yesterdaySummary: _parseYesterdaySummary(json['yesterdaySummary']),
      goals: _parseGoals(json['goals']),
    );
  }

  ({TrainingBlock block, CoachingGoals? goals})
  parseTrainingBlockPlanWithContext(Map<String, dynamic> json) {
    final block = parseTrainingBlockPlan(json);
    return (block: block, goals: _parseGoals(json['goals']));
  }

  static YesterdaySummary? _parseYesterdaySummary(Object? value) {
    if (value is! Map) return null;
    return YesterdaySummary.fromJson(value.cast<String, dynamic>());
  }

  static CoachingGoals? _parseGoals(Object? value) {
    if (value is! Map) return null;
    return CoachingGoals.fromJson(value.cast<String, dynamic>());
  }

  MealAnalysisResult parseNutritionAnalysisResult(Map<String, dynamic> json) {
    final resultJson =
        (json['result'] as Map?)?.cast<String, dynamic>() ?? json;
    final result = MealAnalysisResult.fromJson(resultJson);
    if (result.calories <= 0) {
      throw const FormatException(
        'Nutrition analysis result must include positive calories.',
      );
    }
    if (result.protein < 0 || result.carbs < 0 || result.fat < 0) {
      throw const FormatException(
        'Nutrition analysis result macros cannot be negative.',
      );
    }
    return result;
  }

  FuelGuidance parseFuelGuidance(Map<String, dynamic> json) {
    return FuelGuidance.fromJson(json);
  }

  List<MemoryEntry> extractMemoryWikiEntries(
    Iterable<Map<String, dynamic>?> payloads,
  ) {
    final entries = <MemoryEntry>[];
    for (final json in payloads) {
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

List<Map<String, dynamic>> _activeRecords(List<PersonalRecord> records) {
  return records
      .where((pr) => pr.includeInContext)
      .map((pr) => pr.toJson())
      .toList();
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

Map<String, dynamic> _workoutPayloadObject(Map<String, dynamic> payload) {
  final workout = (payload['workout'] as Map?)?.cast<String, dynamic>();
  if (workout != null) return workout;

  final plan = (payload['plan'] as Map?)?.cast<String, dynamic>();
  if (plan != null) {
    final planWorkout = (plan['workout'] as Map?)?.cast<String, dynamic>();
    if (planWorkout != null) return planWorkout;
    if (plan['items'] is List || plan['exercises'] is List) return plan;
  }

  final result = (payload['result'] as Map?)?.cast<String, dynamic>();
  if (result != null) {
    final resultWorkout = (result['workout'] as Map?)?.cast<String, dynamic>();
    if (resultWorkout != null) return resultWorkout;
    if (result['items'] is List || result['exercises'] is List) return result;
  }

  return payload;
}
