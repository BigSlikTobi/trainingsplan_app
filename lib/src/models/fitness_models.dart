enum Equipment {
  dumbbells('Kurzhanteln'),
  barbell('Langhantel'),
  curlBar('Curlstange'),
  kettlebells('Kettlebells'),
  bands('Elastic Bands'),
  bosu('BOSU-Ball');

  const Equipment(this.label);

  final String label;
}

enum TrainingStyle {
  rugby('Rugby Player', 'Explosive Kraft, Sprints, Kontakte, robuste Athletik'),
  boxer('Boxer', 'Kondition, Rotation, Schultern, Footwork, Core'),
  hybrid('Hybrid Athlete', 'Kraft, Conditioning und Beweglichkeit'),
  strengthHypertrophy(
    'Strength + Hypertrophy',
    'Muskelaufbau mit messbarer Kraft',
  ),
  conditioning('Conditioning', 'Work capacity, Intervalle, Regeneration'),
  custom('Custom', 'Codex definiert den Schwerpunkt');

  const TrainingStyle(this.label, this.description);

  final String label;
  final String description;
}

enum MemoryCategory {
  training('Training'),
  form('Form'),
  nutrition('Nutrition'),
  recovery('Recovery'),
  preference('Preference'),
  constraint('Constraint'),
  goal('Goal');

  const MemoryCategory(this.label);

  final String label;
}

class AthleteProfile {
  const AthleteProfile({
    required this.name,
    required this.goal,
    required this.heightCm,
    required this.weightKg,
    required this.age,
    required this.sex,
    required this.nutritionTarget,
    required this.trainingDays,
    required this.sessionMinutes,
    required this.equipment,
    required this.constraints,
    required this.preferences,
  });

  final String name;
  final String goal;
  final double heightCm;
  final double weightKg;
  final int age;
  final String sex;
  final NutritionTarget nutritionTarget;
  final int trainingDays;
  final int sessionMinutes;
  final List<Equipment> equipment;
  final List<String> constraints;
  final List<String> preferences;

  AthleteProfile copyWith({
    String? name,
    String? goal,
    double? heightCm,
    double? weightKg,
    int? age,
    String? sex,
    NutritionTarget? nutritionTarget,
    int? trainingDays,
    int? sessionMinutes,
    List<Equipment>? equipment,
    List<String>? constraints,
    List<String>? preferences,
  }) {
    return AthleteProfile(
      name: name ?? this.name,
      goal: goal ?? this.goal,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      nutritionTarget: nutritionTarget ?? this.nutritionTarget,
      trainingDays: trainingDays ?? this.trainingDays,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      equipment: equipment ?? this.equipment,
      constraints: constraints ?? this.constraints,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'goal': goal,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'age': age,
    'sex': sex,
    'nutritionTarget': nutritionTarget.toJson(),
    'trainingDays': trainingDays,
    'sessionMinutes': sessionMinutes,
    'equipment': equipment.map((item) => item.name).toList(),
    'constraints': constraints,
    'preferences': preferences,
  };

  factory AthleteProfile.fromJson(Map<String, dynamic> json) {
    return AthleteProfile(
      name: json['name'] as String? ?? 'Tobi',
      goal: json['goal'] as String? ?? 'Muscle + strength',
      heightCm: _doubleValue(json['heightCm'], 182),
      weightKg: _doubleValue(json['weightKg'], 82),
      age: _intValue(json['age'], 35),
      sex: json['sex'] as String? ?? 'unspecified',
      nutritionTarget: NutritionTarget.fromJson(
        (json['nutritionTarget'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      trainingDays: _intValue(json['trainingDays'], 4),
      sessionMinutes: _intValue(json['sessionMinutes'], 55),
      equipment: _enumList(
        json['equipment'],
        Equipment.values,
        Equipment.dumbbells,
      ),
      constraints: _stringList(json['constraints']),
      preferences: _stringList(json['preferences']),
    );
  }
}

class NutritionTarget {
  const NutritionTarget({
    required this.dailyCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.goalMode,
    required this.rationale,
    required this.updatedAt,
    required this.source,
  });

  final int dailyCalories;
  final int protein;
  final int carbs;
  final int fat;
  final String goalMode;
  final String rationale;
  final DateTime updatedAt;
  final String source;

  Map<String, dynamic> toJson() => {
    'dailyCalories': dailyCalories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'goalMode': goalMode,
    'rationale': rationale,
    'updatedAt': updatedAt.toIso8601String(),
    'source': source,
  };

  factory NutritionTarget.fromJson(Map<String, dynamic> json) {
    return NutritionTarget(
      dailyCalories: _intValue(
        json['dailyCalories'] ?? json['calories'] ?? json['targetCalories'],
        2600,
      ),
      protein: _intValue(json['protein'], 170),
      carbs: _intValue(json['carbs'], 280),
      fat: _intValue(json['fat'], 80),
      goalMode: json['goalMode'] as String? ?? 'Codex inferred',
      rationale: json['rationale'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime(2026, 5, 18),
      source: json['source'] as String? ?? 'seed',
    );
  }
}

class ExerciseMedia {
  const ExerciseMedia({
    required this.explainerUrl,
    required this.setup,
    required this.cues,
    required this.commonMistakes,
  });

  final String explainerUrl;
  final String setup;
  final List<String> cues;
  final List<String> commonMistakes;

  Map<String, dynamic> toJson() => {
    'explainerUrl': explainerUrl,
    'setup': setup,
    'cues': cues,
    'commonMistakes': commonMistakes,
  };

  factory ExerciseMedia.fromJson(Map<String, dynamic> json) {
    return ExerciseMedia(
      explainerUrl:
          json['explainerUrl'] as String? ??
          json['youtubeUrl'] as String? ??
          json['videoUrl'] as String? ??
          '',
      setup: json['setup'] as String? ?? '',
      cues: _stringList(json['cues']),
      commonMistakes: _stringList(json['commonMistakes']),
    );
  }
}

class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.name,
    required this.focus,
    required this.equipment,
    required this.media,
  });

  final String id;
  final String name;
  final String focus;
  final Equipment equipment;
  final ExerciseMedia media;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'focus': focus,
    'equipment': equipment.name,
    'media': media.toJson(),
  };

  factory ExerciseDefinition.fromJson(Map<String, dynamic> json) {
    return ExerciseDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      focus: json['focus'] as String? ?? '',
      equipment: _enumValue(
        json['equipment'],
        Equipment.values,
        Equipment.dumbbells,
      ),
      media: ExerciseMedia.fromJson(
        (json['media'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class ExercisePrescription {
  const ExercisePrescription({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.reps,
    required this.targetLoad,
    required this.targetRpe,
    required this.restSeconds,
    required this.coachCue,
    this.media,
  });

  final String exerciseId;
  final String name;
  final int sets;
  final String reps;
  final String targetLoad;
  final double targetRpe;
  final int restSeconds;
  final String coachCue;
  final ExerciseMedia? media;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'name': name,
    'sets': sets,
    'reps': reps,
    'targetLoad': targetLoad,
    'targetRpe': targetRpe,
    'restSeconds': restSeconds,
    'coachCue': coachCue,
    if (media != null) 'media': media!.toJson(),
  };

  factory ExercisePrescription.fromJson(Map<String, dynamic> json) {
    return ExercisePrescription(
      exerciseId: json['exerciseId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sets: _intValue(json['sets'], 3),
      reps: json['reps'] as String? ?? '8-12',
      targetLoad: json['targetLoad'] as String? ?? 'Technisch sauber',
      targetRpe: _doubleValue(json['targetRpe'], 7),
      restSeconds: _intValue(json['restSeconds'], 90),
      coachCue: json['coachCue'] as String? ?? '',
      media: _exerciseMediaValue(json),
    );
  }
}

class PlannedWorkout {
  const PlannedWorkout({
    required this.id,
    required this.week,
    required this.day,
    required this.title,
    required this.focus,
    required this.rationale,
    required this.exercises,
    required this.conditioning,
  });

  final String id;
  final int week;
  final int day;
  final String title;
  final String focus;
  final String rationale;
  final List<ExercisePrescription> exercises;
  final String conditioning;

  Map<String, dynamic> toJson() => {
    'id': id,
    'week': week,
    'day': day,
    'title': title,
    'focus': focus,
    'rationale': rationale,
    'exercises': exercises.map((item) => item.toJson()).toList(),
    'conditioning': conditioning,
  };

  factory PlannedWorkout.fromJson(Map<String, dynamic> json) {
    return PlannedWorkout(
      id: json['id'] as String? ?? _id('workout'),
      week: _intValue(json['week'], 1),
      day: _intValue(json['day'], 1),
      title: json['title'] as String? ?? 'Training',
      focus: json['focus'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      exercises: _objectList(json['exercises'], ExercisePrescription.fromJson),
      conditioning: json['conditioning'] as String? ?? '',
    );
  }
}

class TrainingBlock {
  const TrainingBlock({
    required this.id,
    required this.style,
    required this.title,
    required this.durationWeeks,
    required this.currentWeek,
    required this.weeklyFocus,
    required this.measurableTargets,
    required this.workouts,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final TrainingStyle style;
  final String title;
  final int durationWeeks;
  final int currentWeek;
  final List<String> weeklyFocus;
  final List<String> measurableTargets;
  final List<PlannedWorkout> workouts;
  final String createdBy;
  final DateTime createdAt;

  TrainingBlock copyWith({
    int? currentWeek,
    List<PlannedWorkout>? workouts,
    String? createdBy,
  }) {
    return TrainingBlock(
      id: id,
      style: style,
      title: title,
      durationWeeks: durationWeeks,
      currentWeek: currentWeek ?? this.currentWeek,
      weeklyFocus: weeklyFocus,
      measurableTargets: measurableTargets,
      workouts: workouts ?? this.workouts,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'style': style.name,
    'title': title,
    'durationWeeks': durationWeeks,
    'currentWeek': currentWeek,
    'weeklyFocus': weeklyFocus,
    'measurableTargets': measurableTargets,
    'workouts': workouts.map((item) => item.toJson()).toList(),
    'createdBy': createdBy,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TrainingBlock.fromJson(Map<String, dynamic> json) {
    return TrainingBlock(
      id: json['id'] as String? ?? _id('block'),
      style: _enumValue(
        json['style'],
        TrainingStyle.values,
        TrainingStyle.strengthHypertrophy,
      ),
      title: json['title'] as String? ?? '8 Week Block',
      durationWeeks: _intValue(json['durationWeeks'], 8),
      currentWeek: _intValue(json['currentWeek'], 1),
      weeklyFocus: _stringList(json['weeklyFocus']),
      measurableTargets: _stringList(json['measurableTargets']),
      workouts: _objectList(json['workouts'], PlannedWorkout.fromJson),
      createdBy: json['createdBy'] as String? ?? 'Codex',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class LoggedSet {
  const LoggedSet({
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.rpe,
  });

  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final double weightKg;
  final int reps;
  final double rpe;

  double get volume => weightKg * reps;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'setNumber': setNumber,
    'weightKg': weightKg,
    'reps': reps,
    'rpe': rpe,
  };

  factory LoggedSet.fromJson(Map<String, dynamic> json) {
    return LoggedSet(
      exerciseId: json['exerciseId'] as String? ?? '',
      exerciseName: json['exerciseName'] as String? ?? '',
      setNumber: _intValue(json['setNumber'], 1),
      weightKg: _doubleValue(json['weightKg'], 0),
      reps: _intValue(json['reps'], 0),
      rpe: _doubleValue(json['rpe'], 7),
    );
  }
}

class ExerciseTiming {
  const ExerciseTiming({
    required this.exerciseId,
    required this.exerciseName,
    required this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.pausedSeconds = 0,
    this.healthSnapshot,
    this.notes = '',
  });

  final String exerciseId;
  final String exerciseName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;
  final int pausedSeconds;
  final LiveHealthMetrics? healthSnapshot;
  final String notes;

  bool get isStopped => completedAt != null;
  bool get isPaused => pausedAt != null && !isStopped;
  bool get isRunning => !isStopped && !isPaused;

  /// Active wall time minus all paused intervals.
  int? get durationSeconds {
    final end = completedAt;
    if (end == null) return null;
    final wall = end.difference(startedAt).inSeconds;
    final active = wall - pausedSeconds;
    return active < 0 ? 0 : active;
  }

  ExerciseTiming copyWith({
    DateTime? completedAt,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? pausedSeconds,
    LiveHealthMetrics? healthSnapshot,
    String? notes,
  }) {
    return ExerciseTiming(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      healthSnapshot: healthSnapshot ?? this.healthSnapshot,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'startedAt': startedAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    if (pausedAt != null) 'pausedAt': pausedAt!.toIso8601String(),
    if (pausedSeconds > 0) 'pausedSeconds': pausedSeconds,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (healthSnapshot != null) 'healthSnapshot': healthSnapshot!.toJson(),
    if (notes.isNotEmpty) 'notes': notes,
  };

  factory ExerciseTiming.fromJson(Map<String, dynamic> json) {
    return ExerciseTiming(
      exerciseId: json['exerciseId'] as String? ?? '',
      exerciseName: json['exerciseName'] as String? ?? '',
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      pausedAt: DateTime.tryParse(json['pausedAt'] as String? ?? ''),
      pausedSeconds: _intValue(json['pausedSeconds'], 0),
      healthSnapshot: _healthMetricsValue(json['healthSnapshot']),
      notes: json['notes'] as String? ?? '',
    );
  }
}

class WorkoutLog {
  const WorkoutLog({
    required this.id,
    required this.workoutId,
    required this.title,
    required this.startedAt,
    required this.completedAt,
    required this.readiness,
    required this.soreness,
    required this.notes,
    required this.sets,
    required this.healthWriteStatus,
    this.healthMetrics,
    this.exerciseTimings = const [],
    this.pausedAt,
    this.pausedSeconds = 0,
  });

  final String id;
  final String workoutId;
  final String title;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int readiness;
  final int soreness;
  final String notes;
  final List<LoggedSet> sets;
  final String healthWriteStatus;
  final LiveHealthMetrics? healthMetrics;
  final List<ExerciseTiming> exerciseTimings;
  final DateTime? pausedAt;
  final int pausedSeconds;

  bool get isStopped => completedAt != null;
  bool get isPaused => pausedAt != null && !isStopped;
  bool get isRunning => !isStopped && !isPaused;

  double get totalVolume => sets.fold(0, (sum, item) => sum + item.volume);

  /// Active wall time minus all paused intervals.
  int? get totalDurationSeconds {
    final end = completedAt;
    if (end == null) return null;
    final wall = end.difference(startedAt).inSeconds;
    final active = wall - pausedSeconds;
    return active < 0 ? 0 : active;
  }

  WorkoutLog copyWith({
    DateTime? completedAt,
    int? readiness,
    int? soreness,
    String? notes,
    List<LoggedSet>? sets,
    String? healthWriteStatus,
    LiveHealthMetrics? healthMetrics,
    List<ExerciseTiming>? exerciseTimings,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? pausedSeconds,
  }) {
    return WorkoutLog(
      id: id,
      workoutId: workoutId,
      title: title,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      readiness: readiness ?? this.readiness,
      soreness: soreness ?? this.soreness,
      notes: notes ?? this.notes,
      sets: sets ?? this.sets,
      healthWriteStatus: healthWriteStatus ?? this.healthWriteStatus,
      healthMetrics: healthMetrics ?? this.healthMetrics,
      exerciseTimings: exerciseTimings ?? this.exerciseTimings,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'workoutId': workoutId,
    'title': title,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    if (pausedAt != null) 'pausedAt': pausedAt!.toIso8601String(),
    if (pausedSeconds > 0) 'pausedSeconds': pausedSeconds,
    if (totalDurationSeconds != null)
      'totalDurationSeconds': totalDurationSeconds,
    'readiness': readiness,
    'soreness': soreness,
    'notes': notes,
    'sets': sets.map((item) => item.toJson()).toList(),
    'healthWriteStatus': healthWriteStatus,
    if (healthMetrics != null) 'healthMetrics': healthMetrics!.toJson(),
    if (exerciseTimings.isNotEmpty)
      'exerciseTimings': exerciseTimings.map((item) => item.toJson()).toList(),
  };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'] as String? ?? _id('log'),
      workoutId: json['workoutId'] as String? ?? '',
      title: json['title'] as String? ?? 'Workout',
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      readiness: _intValue(json['readiness'], 3),
      soreness: _intValue(json['soreness'], 2),
      notes: json['notes'] as String? ?? '',
      sets: _objectList(json['sets'], LoggedSet.fromJson),
      healthWriteStatus: json['healthWriteStatus'] as String? ?? 'not_synced',
      healthMetrics: _healthMetricsValue(json['healthMetrics']),
      exerciseTimings: _objectList(
        json['exerciseTimings'],
        ExerciseTiming.fromJson,
      ),
      pausedAt: DateTime.tryParse(json['pausedAt'] as String? ?? ''),
      pausedSeconds: _intValue(json['pausedSeconds'], 0),
    );
  }
}

class LiveHealthMetrics {
  const LiveHealthMetrics({
    required this.updatedAt,
    required this.sampleCount,
    this.heartRateBpm,
    this.steps,
    this.activeEnergyKcal,
    this.bloodOxygenPercent,
  });

  final DateTime updatedAt;
  final int sampleCount;
  final double? heartRateBpm;
  final int? steps;
  final double? activeEnergyKcal;
  final double? bloodOxygenPercent;

  bool get hasAnyValue =>
      heartRateBpm != null ||
      steps != null ||
      activeEnergyKcal != null ||
      bloodOxygenPercent != null;

  Map<String, dynamic> toJson() => {
    'updatedAt': updatedAt.toIso8601String(),
    'sampleCount': sampleCount,
    if (heartRateBpm != null) 'heartRateBpm': heartRateBpm,
    if (steps != null) 'steps': steps,
    if (activeEnergyKcal != null) 'activeEnergyKcal': activeEnergyKcal,
    if (bloodOxygenPercent != null) 'bloodOxygenPercent': bloodOxygenPercent,
  };

  factory LiveHealthMetrics.fromJson(Map<String, dynamic> json) {
    return LiveHealthMetrics(
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      sampleCount: _intValue(json['sampleCount'], 0),
      heartRateBpm: _nullableDoubleValue(json['heartRateBpm']),
      steps: _nullableIntValue(json['steps']),
      activeEnergyKcal: _nullableDoubleValue(json['activeEnergyKcal']),
      bloodOxygenPercent: _nullableDoubleValue(json['bloodOxygenPercent']),
    );
  }
}

class DayActivitySummary {
  const DayActivitySummary({
    required this.readStatus,
    required this.missingPermissions,
    required this.sampleCount,
    this.steps,
    this.activeEnergyKcal,
    this.exerciseMinutes,
    this.appleMoveMinutes,
    this.walkingRunningDistanceMeters,
    this.cyclingDistanceMeters,
    this.flightsClimbed,
    this.restingHeartRateBpm,
    this.averageHeartRateBpm,
    this.minHeartRateBpm,
    this.maxHeartRateBpm,
    this.bloodOxygenPercent,
    this.sleepMinutesByStage = const {},
    this.weightKg,
    this.dietaryEnergyKcal,
    this.dietaryProteinGrams,
    this.dietaryCarbsGrams,
    this.dietaryFatGrams,
  });

  final String readStatus;
  final List<String> missingPermissions;
  final int sampleCount;
  final int? steps;
  final double? activeEnergyKcal;
  final double? exerciseMinutes;
  final double? appleMoveMinutes;
  final double? walkingRunningDistanceMeters;
  final double? cyclingDistanceMeters;
  final int? flightsClimbed;
  final double? restingHeartRateBpm;
  final double? averageHeartRateBpm;
  final double? minHeartRateBpm;
  final double? maxHeartRateBpm;
  final double? bloodOxygenPercent;
  final Map<String, double> sleepMinutesByStage;
  final double? weightKg;
  final double? dietaryEnergyKcal;
  final double? dietaryProteinGrams;
  final double? dietaryCarbsGrams;
  final double? dietaryFatGrams;

  Map<String, dynamic> toJson() => {
    'readStatus': readStatus,
    if (missingPermissions.isNotEmpty) 'missingPermissions': missingPermissions,
    'sampleCount': sampleCount,
    if (steps != null) 'steps': steps,
    if (activeEnergyKcal != null) 'activeEnergyKcal': activeEnergyKcal,
    if (exerciseMinutes != null) 'exerciseMinutes': exerciseMinutes,
    if (appleMoveMinutes != null) 'appleMoveMinutes': appleMoveMinutes,
    if (walkingRunningDistanceMeters != null)
      'walkingRunningDistanceMeters': walkingRunningDistanceMeters,
    if (cyclingDistanceMeters != null)
      'cyclingDistanceMeters': cyclingDistanceMeters,
    if (flightsClimbed != null) 'flightsClimbed': flightsClimbed,
    if (restingHeartRateBpm != null) 'restingHeartRateBpm': restingHeartRateBpm,
    if (averageHeartRateBpm != null) 'averageHeartRateBpm': averageHeartRateBpm,
    if (minHeartRateBpm != null) 'minHeartRateBpm': minHeartRateBpm,
    if (maxHeartRateBpm != null) 'maxHeartRateBpm': maxHeartRateBpm,
    if (bloodOxygenPercent != null) 'bloodOxygenPercent': bloodOxygenPercent,
    if (sleepMinutesByStage.isNotEmpty)
      'sleepMinutesByStage': sleepMinutesByStage,
    if (weightKg != null) 'weightKg': weightKg,
    if (dietaryEnergyKcal != null) 'dietaryEnergyKcal': dietaryEnergyKcal,
    if (dietaryProteinGrams != null) 'dietaryProteinGrams': dietaryProteinGrams,
    if (dietaryCarbsGrams != null) 'dietaryCarbsGrams': dietaryCarbsGrams,
    if (dietaryFatGrams != null) 'dietaryFatGrams': dietaryFatGrams,
  };
}

class DayActivitySession {
  const DayActivitySession({
    required this.id,
    required this.activityType,
    required this.startedAt,
    required this.endedAt,
    this.sourceName,
    this.durationMinutes,
    this.distanceMeters,
    this.activeEnergyKcal,
    this.steps,
    this.averageHeartRateBpm,
  });

  final String id;
  final String activityType;
  final DateTime startedAt;
  final DateTime endedAt;
  final String? sourceName;
  final double? durationMinutes;
  final double? distanceMeters;
  final double? activeEnergyKcal;
  final int? steps;
  final double? averageHeartRateBpm;

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityType': activityType,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    if (sourceName != null) 'sourceName': sourceName,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    if (activeEnergyKcal != null) 'activeEnergyKcal': activeEnergyKcal,
    if (steps != null) 'steps': steps,
    if (averageHeartRateBpm != null) 'averageHeartRateBpm': averageHeartRateBpm,
  };
}

class DayActivityReport {
  const DayActivityReport({required this.summary, required this.sessions});

  final DayActivitySummary summary;
  final List<DayActivitySession> sessions;

  Map<String, dynamic> toJson() => {
    'summary': summary.toJson(),
    'sessions': sessions.map((item) => item.toJson()).toList(),
  };
}

class NutritionLog {
  const NutritionLog({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.bodyWeightKg,
    required this.notes,
  });

  final DateTime date;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final double bodyWeightKg;
  final String notes;

  int get adherenceScore {
    final proteinScore = protein >= 160 ? 35 : (protein / 160 * 35).round();
    final calorieScore = calories >= 2200 && calories <= 3100 ? 35 : 20;
    final noteScore = notes.trim().isEmpty ? 10 : 30;
    return (proteinScore + calorieScore + noteScore).clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
    'date': _dateKey(date),
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'bodyWeightKg': bodyWeightKg,
    'notes': notes,
  };

  factory NutritionLog.fromJson(Map<String, dynamic> json) {
    return NutritionLog(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      calories: _intValue(json['calories'], 2600),
      protein: _intValue(json['protein'], 170),
      carbs: _intValue(json['carbs'], 280),
      fat: _intValue(json['fat'], 80),
      bodyWeightKg: _doubleValue(json['bodyWeightKg'], 82),
      notes: json['notes'] as String? ?? '',
    );
  }
}

class MealAnalysisRequest {
  const MealAnalysisRequest({
    required this.id,
    required this.createdAt,
    required this.description,
    required this.imagePath,
    required this.status,
  });

  final String id;
  final DateTime createdAt;
  final String description;
  final String? imagePath;
  final String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'description': description,
    'imagePath': imagePath,
    'status': status,
  };

  factory MealAnalysisRequest.fromJson(Map<String, dynamic> json) {
    return MealAnalysisRequest(
      id: json['id'] as String? ?? _id('meal_request'),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      description: json['description'] as String? ?? '',
      imagePath: json['imagePath'] as String?,
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class MealAnalysisResult {
  const MealAnalysisResult({
    required this.id,
    required this.requestId,
    required this.analyzedAt,
    required this.mealDescription,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.bodyWeightKg,
    required this.confidence,
    required this.assumptions,
    required this.rationale,
    required this.correctionNotes,
    required this.target,
  });

  final String id;
  final String requestId;
  final DateTime analyzedAt;
  final String mealDescription;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final double bodyWeightKg;
  final double confidence;
  final List<String> assumptions;
  final String rationale;
  final String correctionNotes;
  final NutritionTarget? target;

  NutritionLog toNutritionLog({String? notes}) {
    final noteParts = [
      if (notes != null && notes.trim().isNotEmpty) notes.trim(),
      if (mealDescription.trim().isNotEmpty) mealDescription.trim(),
      if (rationale.trim().isNotEmpty) 'Codex: ${rationale.trim()}',
      if (assumptions.isNotEmpty) 'Assumptions: ${assumptions.join('; ')}',
      'Confidence ${(confidence * 100).round()}%',
    ];
    return NutritionLog(
      date: DateTime.now(),
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      bodyWeightKg: bodyWeightKg,
      notes: noteParts.join('\n'),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'requestId': requestId,
    'analyzedAt': analyzedAt.toIso8601String(),
    'mealDescription': mealDescription,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'bodyWeightKg': bodyWeightKg,
    'confidence': confidence,
    'assumptions': assumptions,
    'rationale': rationale,
    'correctionNotes': correctionNotes,
    if (target != null) 'target': target!.toJson(),
  };

  factory MealAnalysisResult.fromJson(Map<String, dynamic> json) {
    final macros = (json['macros'] as Map?)?.cast<String, dynamic>();
    final targetJson =
        (json['target'] as Map?)?.cast<String, dynamic>() ??
        (json['nutritionTarget'] as Map?)?.cast<String, dynamic>();
    return MealAnalysisResult(
      id: json['id'] as String? ?? _id('meal_result'),
      requestId: json['requestId'] as String? ?? '',
      analyzedAt:
          DateTime.tryParse(json['analyzedAt'] as String? ?? '') ??
          DateTime.now(),
      mealDescription:
          json['mealDescription'] as String? ??
          json['description'] as String? ??
          '',
      calories: _intValue(json['calories'] ?? macros?['calories'], 0),
      protein: _intValue(json['protein'] ?? macros?['protein'], 0),
      carbs: _intValue(json['carbs'] ?? macros?['carbs'], 0),
      fat: _intValue(json['fat'] ?? macros?['fat'], 0),
      bodyWeightKg: _doubleValue(json['bodyWeightKg'], 82),
      confidence: _doubleValue(json['confidence'], .65).clamp(0, 1).toDouble(),
      assumptions: _stringList(json['assumptions']),
      rationale: json['rationale'] as String? ?? '',
      correctionNotes: json['correctionNotes'] as String? ?? '',
      target: targetJson == null ? null : NutritionTarget.fromJson(targetJson),
    );
  }
}

enum FuelSignal { green, hold, fuel, deload }

class MealSuggestion {
  const MealSuggestion({
    required this.name,
    required this.rationale,
    required this.timing,
  });

  final String name;
  final String rationale;
  final String timing;

  Map<String, dynamic> toJson() => {
    'name': name,
    'rationale': rationale,
    'timing': timing,
  };

  factory MealSuggestion.fromJson(Map<String, dynamic> json) {
    return MealSuggestion(
      name: json['name'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      timing: json['timing'] as String? ?? '',
    );
  }
}

class MealIdea {
  const MealIdea({
    required this.tag,
    required this.name,
    required this.why,
  });

  final String tag;
  final String name;
  final String why;

  Map<String, dynamic> toJson() => {
    'tag': tag,
    'name': name,
    'why': why,
  };

  factory MealIdea.fromJson(Map<String, dynamic> json) {
    return MealIdea(
      tag: json['tag'] as String? ?? 'any-time',
      name: json['name'] as String? ?? '',
      why: json['why'] as String? ?? '',
    );
  }
}

class FuelGuidance {
  const FuelGuidance({
    required this.issuedAt,
    required this.validFor,
    required this.signal,
    required this.signalLabel,
    required this.signalSub,
    required this.todayAdvice,
    required this.mealSuggestion,
    required this.yesterdayRead,
    required this.mealIdeas,
  });

  final DateTime issuedAt;
  final String validFor;
  final FuelSignal signal;
  final String signalLabel;
  final String signalSub;
  final String todayAdvice;
  final MealSuggestion mealSuggestion;
  final String yesterdayRead;
  final List<MealIdea> mealIdeas;

  Map<String, dynamic> toJson() => {
    'schema': 'fuel_guidance.v1',
    'issuedAt': issuedAt.toIso8601String(),
    'validFor': validFor,
    'signal': signal.name,
    'signalLabel': signalLabel,
    'signalSub': signalSub,
    'todayAdvice': todayAdvice,
    'mealSuggestion': mealSuggestion.toJson(),
    'yesterdayRead': yesterdayRead,
    'mealIdeas': mealIdeas.map((item) => item.toJson()).toList(),
  };

  factory FuelGuidance.fromJson(Map<String, dynamic> json) {
    final suggestionJson =
        (json['mealSuggestion'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return FuelGuidance(
      issuedAt:
          DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
          DateTime.now(),
      validFor: json['validFor'] as String? ?? '',
      signal: _enumValue(json['signal'], FuelSignal.values, FuelSignal.hold),
      signalLabel: json['signalLabel'] as String? ?? '',
      signalSub: json['signalSub'] as String? ?? '',
      todayAdvice: json['todayAdvice'] as String? ?? '',
      mealSuggestion: MealSuggestion.fromJson(suggestionJson),
      yesterdayRead: json['yesterdayRead'] as String? ?? '',
      mealIdeas: _objectList(json['mealIdeas'], MealIdea.fromJson),
    );
  }
}

class CoachDecision {
  const CoachDecision({
    required this.id,
    required this.createdAt,
    required this.title,
    required this.rationale,
    required this.safetyFlags,
    required this.accepted,
  });

  final String id;
  final DateTime createdAt;
  final String title;
  final String rationale;
  final List<String> safetyFlags;
  final bool accepted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'title': title,
    'rationale': rationale,
    'safetyFlags': safetyFlags,
    'accepted': accepted,
  };

  factory CoachDecision.fromJson(Map<String, dynamic> json) {
    return CoachDecision(
      id: json['id'] as String? ?? _id('decision'),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      title: json['title'] as String? ?? 'Coach update',
      rationale: json['rationale'] as String? ?? '',
      safetyFlags: _stringList(json['safetyFlags']),
      accepted: _boolValue(json['accepted'], false),
    );
  }
}

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
    required this.title,
    required this.summary,
    required this.markdown,
    required this.source,
    required this.confidence,
    required this.active,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MemoryCategory category;
  final String title;
  final String summary;
  final String markdown;
  final String source;
  final double confidence;
  final bool active;

  MemoryEntry copyWith({
    DateTime? updatedAt,
    MemoryCategory? category,
    String? title,
    String? summary,
    String? markdown,
    String? source,
    double? confidence,
    bool? active,
  }) {
    return MemoryEntry(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      markdown: markdown ?? this.markdown,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'category': category.name,
    'title': title,
    'summary': summary,
    'markdown': markdown,
    'source': source,
    'confidence': confidence,
    'active': active,
  };

  Map<String, dynamic> toPromptJson() => {
    'category': category.name,
    'title': title,
    'summary': summary,
    if (markdown.trim().isNotEmpty) 'markdown': markdown,
    'source': source,
    'confidence': confidence,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return MemoryEntry(
      id: json['id'] as String? ?? _id('memory'),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
      category: _enumValue(
        json['category'],
        MemoryCategory.values,
        MemoryCategory.training,
      ),
      title: json['title'] as String? ?? 'Memory',
      summary: json['summary'] as String? ?? '',
      markdown: json['markdown'] as String? ?? '',
      source: json['source'] as String? ?? 'manual',
      confidence: _doubleValue(json['confidence'], 1).clamp(0, 1).toDouble(),
      active: _boolValue(json['active'], true),
    );
  }
}

class FitnessData {
  const FitnessData({
    required this.profile,
    required this.blocks,
    required this.activeBlockId,
    required this.logs,
    required this.nutrition,
    required this.pendingMealRequest,
    required this.pendingMealResult,
    required this.coachDecisions,
    required this.memories,
    this.fuelGuidance,
  });

  final AthleteProfile profile;
  final List<TrainingBlock> blocks;
  final String? activeBlockId;
  final List<WorkoutLog> logs;
  final List<NutritionLog> nutrition;
  final MealAnalysisRequest? pendingMealRequest;
  final MealAnalysisResult? pendingMealResult;
  final List<CoachDecision> coachDecisions;
  final List<MemoryEntry> memories;
  final FuelGuidance? fuelGuidance;

  TrainingBlock? get activeBlock {
    for (final block in blocks) {
      if (block.id == activeBlockId) return block;
    }
    return blocks.isEmpty ? null : blocks.first;
  }

  bool get hasActiveWorkout => logs.any((log) => log.completedAt == null);

  PlannedWorkout? get nextWorkout {
    final block = activeBlock;
    if (block == null || block.workouts.isEmpty) return null;
    final completedIds = logs
        .where((log) => log.completedAt != null)
        .map((log) => log.workoutId)
        .toSet();
    for (final workout in block.workouts) {
      if (!completedIds.contains(workout.id)) return workout;
    }
    return block.workouts.last;
  }

  FitnessData copyWith({
    AthleteProfile? profile,
    List<TrainingBlock>? blocks,
    String? activeBlockId,
    List<WorkoutLog>? logs,
    List<NutritionLog>? nutrition,
    Object? pendingMealRequest = _sentinel,
    Object? pendingMealResult = _sentinel,
    List<CoachDecision>? coachDecisions,
    List<MemoryEntry>? memories,
    Object? fuelGuidance = _sentinel,
  }) {
    return FitnessData(
      profile: profile ?? this.profile,
      blocks: blocks ?? this.blocks,
      activeBlockId: activeBlockId ?? this.activeBlockId,
      logs: logs ?? this.logs,
      nutrition: nutrition ?? this.nutrition,
      pendingMealRequest: pendingMealRequest == _sentinel
          ? this.pendingMealRequest
          : pendingMealRequest as MealAnalysisRequest?,
      pendingMealResult: pendingMealResult == _sentinel
          ? this.pendingMealResult
          : pendingMealResult as MealAnalysisResult?,
      coachDecisions: coachDecisions ?? this.coachDecisions,
      memories: memories ?? this.memories,
      fuelGuidance: fuelGuidance == _sentinel
          ? this.fuelGuidance
          : fuelGuidance as FuelGuidance?,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'profile': profile.toJson(),
    'blocks': blocks.map((item) => item.toJson()).toList(),
    'activeBlockId': activeBlockId,
    'logs': logs.map((item) => item.toJson()).toList(),
    'nutrition': nutrition.map((item) => item.toJson()).toList(),
    'pendingMealRequest': pendingMealRequest?.toJson(),
    'pendingMealResult': pendingMealResult?.toJson(),
    'coachDecisions': coachDecisions.map((item) => item.toJson()).toList(),
    'memories': memories.map((item) => item.toJson()).toList(),
    if (fuelGuidance != null) 'fuelGuidance': fuelGuidance!.toJson(),
  };

  factory FitnessData.fromJson(Map<String, dynamic> json) {
    return FitnessData(
      profile: AthleteProfile.fromJson(
        (json['profile'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      blocks: _objectList(json['blocks'], TrainingBlock.fromJson),
      activeBlockId: json['activeBlockId'] as String?,
      logs: _objectList(json['logs'], WorkoutLog.fromJson),
      nutrition: _objectList(json['nutrition'], NutritionLog.fromJson),
      pendingMealRequest: _mealAnalysisRequestValue(json['pendingMealRequest']),
      pendingMealResult: _mealAnalysisResultValue(json['pendingMealResult']),
      coachDecisions: _objectList(
        json['coachDecisions'],
        CoachDecision.fromJson,
      ),
      memories: _objectList(json['memories'], MemoryEntry.fromJson),
      fuelGuidance: _fuelGuidanceValue(json['fuelGuidance']),
    );
  }
}

const Object _sentinel = Object();

String newId(String prefix) => _id(prefix);

String dateKey(DateTime date) => _dateKey(date);

String _id(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

T _enumValue<T extends Enum>(Object? value, List<T> values, T fallback) {
  final text = value?.toString();
  for (final item in values) {
    if (item.name == text) return item;
  }
  return fallback;
}

List<T> _enumList<T extends Enum>(Object? value, List<T> values, T fallback) {
  if (value is! List) return [fallback];
  return value.map((item) => _enumValue(item, values, fallback)).toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}

ExerciseMedia? _exerciseMediaValue(Map<String, dynamic> json) {
  final mediaJson = (json['media'] as Map?)?.cast<String, dynamic>();
  if (mediaJson != null) return ExerciseMedia.fromJson(mediaJson);

  final hasFlatMedia =
      json.containsKey('explainerUrl') ||
      json.containsKey('youtubeUrl') ||
      json.containsKey('videoUrl') ||
      json.containsKey('setup') ||
      json.containsKey('cues') ||
      json.containsKey('commonMistakes');
  if (!hasFlatMedia) return null;

  return ExerciseMedia.fromJson({
    'explainerUrl': json['explainerUrl'],
    'youtubeUrl': json['youtubeUrl'],
    'videoUrl': json['videoUrl'],
    'setup': json['setup'],
    'cues': json['cues'],
    'commonMistakes': json['commonMistakes'],
  });
}

int _intValue(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

double _doubleValue(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

int? _nullableIntValue(Object? value) {
  if (value == null) return null;
  return _intValue(value, 0);
}

double? _nullableDoubleValue(Object? value) {
  if (value == null) return null;
  return _doubleValue(value, 0);
}

bool _boolValue(Object? value, bool fallback) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return fallback;
}

List<T> _objectList<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => fromJson(item.cast<String, dynamic>()))
      .toList();
}

LiveHealthMetrics? _healthMetricsValue(Object? value) {
  if (value is! Map) return null;
  return LiveHealthMetrics.fromJson(value.cast<String, dynamic>());
}

MealAnalysisRequest? _mealAnalysisRequestValue(Object? value) {
  if (value is! Map) return null;
  return MealAnalysisRequest.fromJson(value.cast<String, dynamic>());
}

MealAnalysisResult? _mealAnalysisResultValue(Object? value) {
  if (value is! Map) return null;
  return MealAnalysisResult.fromJson(value.cast<String, dynamic>());
}

FuelGuidance? _fuelGuidanceValue(Object? value) {
  if (value is! Map) return null;
  return FuelGuidance.fromJson(value.cast<String, dynamic>());
}
