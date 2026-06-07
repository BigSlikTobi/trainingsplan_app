import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/coach_payload_service.dart';

import 'helpers/sample_fitness_data.dart';

void main() {
  test('unfinished workout log keeps workout active and next', () {
    final data = sampleFitnessData();
    final workout = data.nextWorkout!;
    final activeLog = WorkoutLog(
      id: 'log-active',
      workoutId: workout.id,
      title: workout.title,
      startedAt: DateTime(2026),
      completedAt: null,
      readiness: 3,
      soreness: 2,
      notes: '',
      sets: const [],
      healthWriteStatus: 'not_synced',
    );

    final updated = data.copyWith(logs: [activeLog]);

    expect(updated.hasActiveWorkout, isTrue);
    expect(updated.nextWorkout?.id, workout.id);
  });

  test('completed workout log advances next workout', () {
    final data = sampleFitnessData();
    final workout = data.nextWorkout!;
    final completedLog = WorkoutLog(
      id: 'log-completed',
      workoutId: workout.id,
      title: workout.title,
      startedAt: DateTime(2026),
      completedAt: DateTime(2026, 1, 1, 1),
      readiness: 3,
      soreness: 2,
      notes: '',
      sets: const [],
      healthWriteStatus: 'not_synced',
    );

    final updated = data.copyWith(logs: [completedLog]);

    expect(updated.hasActiveWorkout, isFalse);
    expect(updated.nextWorkout?.id, isNot(workout.id));
  });

  test('completed active block has no next workout', () {
    final data = sampleFitnessData();
    final block = data.activeBlock!;
    final logs = [
      for (final workout in block.workouts)
        WorkoutLog(
          id: 'log-${workout.id}',
          workoutId: workout.id,
          title: workout.title,
          startedAt: DateTime(2026),
          completedAt: DateTime(2026, 1, workout.day, 1),
          readiness: 3,
          soreness: 2,
          notes: '',
          sets: const [],
          healthWriteStatus: 'not_synced',
        ),
    ];

    final updated = data.copyWith(logs: logs);

    expect(updated.hasActiveWorkout, isFalse);
    expect(updated.nextWorkout, isNull);
  });

  test('duplicate workout ids only consume one completed occurrence', () {
    final data = sampleFitnessData();
    final baseWorkout = data.activeBlock!.workouts.first;
    final firstDuplicate = PlannedWorkout(
      id: 'duplicate_workout',
      week: 1,
      day: 1,
      title: 'Duplicate A',
      focus: 'First duplicate',
      rationale: '',
      exercises: baseWorkout.exercises,
      conditioning: '',
    );
    final secondDuplicate = PlannedWorkout(
      id: 'duplicate_workout',
      week: 1,
      day: 2,
      title: 'Duplicate B',
      focus: 'Second duplicate',
      rationale: '',
      exercises: baseWorkout.exercises,
      conditioning: '',
    );
    final block = TrainingBlock(
      id: 'duplicate_block',
      style: TrainingStyle.strengthHypertrophy,
      title: 'Duplicate Block',
      durationWeeks: 1,
      currentWeek: 1,
      weeklyFocus: const [],
      measurableTargets: const [],
      workouts: [firstDuplicate, secondDuplicate],
      createdBy: 'test',
      createdAt: DateTime(2026),
    );
    final completedLog = WorkoutLog(
      id: 'log-duplicate-a',
      workoutId: firstDuplicate.id,
      title: firstDuplicate.title,
      startedAt: DateTime(2026),
      completedAt: DateTime(2026, 1, 1, 1),
      readiness: 3,
      soreness: 2,
      notes: '',
      sets: const [],
      healthWriteStatus: 'not_synced',
    );

    final updated = data.copyWith(
      blocks: [block],
      activeBlockId: block.id,
      logs: [completedLog],
    );

    expect(updated.nextWorkout?.title, 'Duplicate B');
  });

  test('live health metrics reports when any realtime value exists', () {
    final empty = LiveHealthMetrics(updatedAt: DateTime(2026), sampleCount: 0);
    final withHeartRate = LiveHealthMetrics(
      updatedAt: DateTime(2026),
      sampleCount: 1,
      heartRateBpm: 128,
    );

    expect(empty.hasAnyValue, isFalse);
    expect(withHeartRate.hasAnyValue, isTrue);
  });

  test('workout log serializes health metrics for T4L Gym Bro context', () {
    final log = WorkoutLog(
      id: 'log-health',
      workoutId: 'workout-health',
      title: 'Health workout',
      startedAt: DateTime(2026, 5, 19, 10),
      completedAt: DateTime(2026, 5, 19, 11),
      readiness: 3,
      soreness: 2,
      notes: '',
      sets: const [],
      healthWriteStatus: 'written_to_apple_health',
      healthMetrics: LiveHealthMetrics(
        updatedAt: DateTime(2026, 5, 19, 10, 59),
        sampleCount: 4,
        heartRateBpm: 128,
        steps: 420,
        activeEnergyKcal: 86,
        bloodOxygenPercent: 98,
      ),
    );

    final decoded = WorkoutLog.fromJson(log.toJson());

    expect(decoded.healthMetrics?.heartRateBpm, 128);
    expect(decoded.healthMetrics?.steps, 420);
    expect(decoded.healthMetrics?.activeEnergyKcal, 86);
    expect(decoded.healthMetrics?.bloodOxygenPercent, 98);
  });

  test('profile nutrition fields and meal analysis result round trip', () {
    final data = sampleFitnessData();
    final result = MealAnalysisResult(
      id: 'meal_result_test',
      requestId: 'meal_request_test',
      analyzedAt: DateTime(2026, 5, 19, 13),
      mealDescription: 'Chicken rice bowl',
      calories: 780,
      protein: 48,
      carbs: 82,
      fat: 28,
      bodyWeightKg: 82,
      confidence: .72,
      assumptions: const ['Rice estimated from image'],
      rationale: 'Training day lunch.',
      correctionNotes: 'Correct rice portion if needed.',
      target: NutritionTarget(
        dailyCalories: 2750,
        protein: 175,
        carbs: 320,
        fat: 80,
        goalMode: 'T4L Gym Bro inferred recomposition',
        rationale: 'Recent training volume is high.',
        updatedAt: DateTime(2026, 5, 19, 13),
        source: 'T4L Gym Bro',
      ),
    );

    final decoded = FitnessData.fromJson(
      data.copyWith(pendingMealResult: result).toJson(),
    );

    expect(decoded.profile.heightCm, 182);
    expect(decoded.profile.weightKg, 82);
    expect(decoded.profile.nutritionTarget.dailyCalories, 2600);
    expect(decoded.pendingMealResult?.calories, 780);
    expect(decoded.pendingMealResult?.target?.dailyCalories, 2750);
    expect(decoded.pendingMealResult?.assumptions, [
      'Rice estimated from image',
    ]);
  });

  test(
    'memory entries serialize and old fitness data loads without memories',
    () {
      final memory = MemoryEntry(
        id: 'memory_form',
        createdAt: DateTime(2026, 5, 20, 9),
        updatedAt: DateTime(2026, 5, 20, 10),
        category: MemoryCategory.form,
        title: 'Squat cue',
        summary: 'Keep heel pressure during goblet squats.',
        markdown: 'Observed during block week 1.',
        source: 'manual',
        confidence: .9,
        active: true,
      );

      final decoded = MemoryEntry.fromJson(memory.toJson());
      final oldJson = sampleFitnessData().toJson()..remove('memories');
      final oldData = FitnessData.fromJson(oldJson);

      expect(decoded.category, MemoryCategory.form);
      expect(decoded.summary, 'Keep heel pressure during goblet squats.');
      expect(
        decoded.toPromptJson()['markdown'],
        'Observed during block week 1.',
      );
      expect(oldData.memories, isEmpty);
    },
  );

  test('training block import accepts numeric strings', () {
    final block = TrainingBlock.fromJson({
      'id': 'block-import',
      'style': 'strengthHypertrophy',
      'title': 'Imported Block',
      'durationWeeks': '8',
      'currentWeek': '1',
      'weeklyFocus': ['Base'],
      'measurableTargets': ['Consistency'],
      'workouts': [
        {
          'id': 'w1d1',
          'week': '1',
          'day': '1',
          'title': 'Day 1',
          'focus': 'Strength',
          'rationale': 'Build capacity.',
          'conditioning': '10 minutes easy bike',
          'exercises': [
            {
              'exerciseId': 'goblet_squat',
              'name': 'Goblet Squat',
              'sets': '3',
              'reps': '8-10',
              'targetLoad': 'moderate',
              'targetRpe': '7.5',
              'restSeconds': '90',
              'coachCue': 'Brace before each rep.',
              'media': {
                'youtubeUrl': 'https://www.youtube.com/watch?v=goblet',
                'setup': 'Kettlebell tight to sternum.',
                'cues': ['Tripod foot', 'Brace hard'],
                'commonMistakes': ['Losing heel pressure'],
              },
            },
          ],
        },
      ],
      'createdBy': 'T4L Gym Bro',
      'createdAt': '2026-05-19T12:00:00.000',
    });

    expect(block.durationWeeks, 8);
    expect(block.currentWeek, 1);
    expect(block.workouts.single.week, 1);
    expect(block.workouts.single.day, 1);
    expect(block.workouts.single.exercises.single.sets, 3);
    expect(block.workouts.single.exercises.single.targetRpe, 7.5);
    expect(block.workouts.single.exercises.single.restSeconds, 90);
    expect(
      block.workouts.single.exercises.single.media?.setup,
      'Kettlebell tight to sternum.',
    );
    expect(
      block.workouts.single.exercises.single.media?.explainerUrl,
      'https://www.youtube.com/watch?v=goblet',
    );
    expect(block.workouts.single.exercises.single.media?.cues, [
      'Tripod foot',
      'Brace hard',
    ]);
    expect(block.workouts.single.exercises.single.media?.commonMistakes, [
      'Losing heel pressure',
    ]);
  });

  test('exercise prescription accepts flat coach cue fields', () {
    final exercise = ExercisePrescription.fromJson({
      'exerciseId': 'push_up',
      'name': 'Push-up',
      'sets': 3,
      'reps': '8-12',
      'targetLoad': 'bodyweight',
      'targetRpe': 7,
      'restSeconds': 60,
      'coachCue': 'Own the plank.',
      'youtubeUrl': 'https://www.youtube.com/watch?v=pushup',
      'setup': 'Hands under shoulders, ribs down.',
      'cues': ['Push the floor away'],
      'commonMistakes': ['Hips sag'],
    });

    expect(
      exercise.media?.explainerUrl,
      'https://www.youtube.com/watch?v=pushup',
    );
    expect(exercise.media?.setup, 'Hands under shoulders, ribs down.');
    expect(exercise.media?.cues, ['Push the floor away']);
    expect(exercise.media?.commonMistakes, ['Hips sag']);
  });

  test('exercise prescription display fields are optional with fallbacks', () {
    final legacy = ExercisePrescription.fromJson({
      'exerciseId': 'squat',
      'name': 'Squat',
      'targetLoad': 'Use the heaviest load that keeps tempo consistent.',
      'coachCue': 'Brace and keep pressure through the midfoot.',
    });
    final mobile = ExercisePrescription.fromJson({
      'exerciseId': 'press',
      'name': 'Press',
      'targetLoad':
          'Ramp across sets from 12 kg to 24 kg if RPE stays below 8.',
      'loadLabel': '12-24 kg',
      'coachCue': 'Press without rib flare and keep the lockout stacked.',
      'primaryCue': 'Ribs down',
      'detailNote': 'Use the long note in details, not on the row.',
      'warningCue': 'Stop for shoulder pinch.',
    });

    expect(
      legacy.displayLoadLabel,
      'Use the heaviest load that keeps tempo consistent.',
    );
    expect(
      legacy.displayPrimaryCue,
      'Brace and keep pressure through the midfoot.',
    );
    expect(mobile.displayLoadLabel, '12-24 kg');
    expect(mobile.displayPrimaryCue, 'Ribs down');
    expect(
      mobile.displayDetailNote,
      'Use the long note in details, not on the row.',
    );
    expect(mobile.displayWarningCue, 'Stop for shoulder pinch.');
    expect(mobile.toJson()['loadLabel'], '12-24 kg');
    expect(mobile.toJson()['primaryCue'], 'Ribs down');
  });

  test('workout items expand supersets by round', () {
    final workout = PlannedWorkout.fromJson({
      'id': 'grouped_day',
      'week': 1,
      'day': 1,
      'title': 'Grouped Day',
      'focus': 'Density',
      'rationale': 'Alternate paired lifts.',
      'conditioning': '',
      'items': [
        {
          'type': 'superset',
          'groupId': 'ss_1',
          'title': 'Superset 1',
          'rounds': 3,
          'restSeconds': 90,
          'exercises': [
            {
              'exerciseId': 'push_up',
              'name': 'Push-Up',
              'sets': 1,
              'reps': '10',
              'targetLoad': 'bodyweight',
              'targetRpe': 7,
              'restSeconds': 0,
              'coachCue': 'Brace.',
            },
            {
              'exerciseId': 'row',
              'name': 'Row',
              'sets': 1,
              'reps': '12',
              'targetLoad': 'moderate',
              'targetRpe': 7,
              'restSeconds': 0,
              'coachCue': 'Pull elbows back.',
            },
          ],
        },
      ],
    });

    expect(workout.exercises.map((e) => e.exerciseId), ['push_up', 'row']);
    expect(workout.exercises.first.sets, 3);
    expect(workout.totalPlannedSets, 6);
    expect(workout.executionSteps.map((s) => s.exercise.exerciseId), [
      'push_up',
      'row',
      'push_up',
      'row',
      'push_up',
      'row',
    ]);
    expect(workout.executionSteps[2].round, 2);
    expect(workout.executionSteps[1].restSeconds, 90);
    expect(workout.toJson(), contains('items'));
    expect(workout.toJson(), isNot(contains('exercises')));
    expect(workout.toWatchJson()['executionSteps'], hasLength(6));
  });

  test('workout item validation rejects malformed groups', () {
    Map<String, dynamic> exercise(String id) => {
      'exerciseId': id,
      'name': id,
      'sets': 1,
      'reps': '10',
      'targetLoad': 'bodyweight',
      'targetRpe': 7,
      'restSeconds': 0,
      'coachCue': '',
    };

    expect(
      () => PlannedWorkout.fromJson({
        'items': [
          {
            'type': 'superset',
            'groupId': 'bad_ss',
            'rounds': 2,
            'exercises': [exercise('a')],
          },
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => PlannedWorkout.fromJson({
        'items': [
          {
            'type': 'circle',
            'groupId': 'bad_circle',
            'rounds': 2,
            'exercises': [exercise('a'), exercise('b'), exercise('c')],
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('FuelGuidance round-trips through toJson / fromJson', () {
    final guidance = FuelGuidance(
      issuedAt: DateTime.utc(2026, 5, 20, 7),
      validFor: '2026-05-20',
      signal: FuelSignal.green,
      signalLabel: 'GREEN LIGHT',
      signalSub: 'Fuel und Readiness im Einklang.',
      todayAdvice: 'Protein ist heute der Hebel — 30–40g pro Hauptmahlzeit.',
      mealSuggestion: const MealSuggestion(
        name: 'Spaghetti Carbonara',
        rationale: 'Pasta füllt Glykogen, Eier liefern Protein.',
        timing: 'post-training',
      ),
      yesterdayRead: 'Solide Basis — passt zum heutigen Krafttraining.',
      mealIdeas: const [
        MealIdea(
          tag: 'pre-training',
          name: 'Haferflocken + Banane',
          why: 'Schnelle Kohlenhydrate vor der Session.',
        ),
        MealIdea(
          tag: 'post-training',
          name: 'Chicken Rice Bowl',
          why: 'Sauberes Protein und Kohlenhydrat-Basis.',
        ),
        MealIdea(
          tag: 'any-time',
          name: 'Joghurt + Beeren',
          why: 'Leicht und proteinreich.',
        ),
      ],
    );

    final decoded = FuelGuidance.fromJson(guidance.toJson());

    expect(decoded.validFor, '2026-05-20');
    expect(decoded.signal, FuelSignal.green);
    expect(decoded.signalLabel, 'GREEN LIGHT');
    expect(decoded.signalSub, 'Fuel und Readiness im Einklang.');
    expect(decoded.todayAdvice, contains('Protein'));
    expect(decoded.mealSuggestion.name, 'Spaghetti Carbonara');
    expect(decoded.mealSuggestion.timing, 'post-training');
    expect(
      decoded.yesterdayRead,
      'Solide Basis — passt zum heutigen Krafttraining.',
    );
    expect(decoded.mealIdeas, hasLength(3));
    expect(decoded.mealIdeas.first.tag, 'pre-training');
    expect(decoded.mealIdeas.first.name, 'Haferflocken + Banane');
  });

  test('FuelGuidance unknown signal falls back to hold', () {
    final json = {
      'schema': 'fuel_guidance.v1',
      'issuedAt': '2026-05-20T07:00:00Z',
      'validFor': '2026-05-20',
      'signal': 'totally_unknown_value',
      'signalLabel': 'UNKNOWN',
      'signalSub': '',
      'todayAdvice': '',
      'mealSuggestion': <String, dynamic>{},
      'yesterdayRead': '',
      'mealIdeas': <dynamic>[],
    };

    final decoded = FuelGuidance.fromJson(json);
    expect(decoded.signal, FuelSignal.hold);
  });

  test('FuelGuidance round-trips through FitnessData toJson / fromJson', () {
    final data = sampleFitnessData();
    final guidance2 = FuelGuidance(
      issuedAt: DateTime.utc(2026, 5, 20, 7),
      validFor: '2026-05-20',
      signal: FuelSignal.fuel,
      signalLabel: 'FUEL FIRST',
      signalSub: 'Heute vor dem Training auftanken.',
      todayAdvice: 'Kohlenhydratreiche Mahlzeit 2–3h vor der Session.',
      mealSuggestion: const MealSuggestion(
        name: 'Haferflocken + Banane',
        rationale: 'Schnelle Kohlenhydrate.',
        timing: 'pre-training',
      ),
      yesterdayRead: 'Niedrig auf ganzer Linie.',
      mealIdeas: const [],
    );

    final withGuidance = data.copyWith(fuelGuidance: guidance2);
    final decoded = FitnessData.fromJson(withGuidance.toJson());

    expect(decoded.fuelGuidance?.signal, FuelSignal.fuel);
    expect(decoded.fuelGuidance?.validFor, '2026-05-20');
    expect(decoded.fuelGuidance?.mealSuggestion.name, 'Haferflocken + Banane');
    expect(decoded.fuelGuidance?.mealIdeas, isEmpty);
  });

  test('FuelCheckIn round-trips through FitnessData toJson / fromJson', () {
    final data = sampleFitnessData().copyWith(
      latestFuelCheckIn: FuelCheckIn(
        guidanceValidFor: '2026-05-25',
        score: 3,
        context: 'Restaurant meal before training.',
        createdAt: DateTime(2026, 5, 25, 20, 30),
      ),
    );

    final decoded = FitnessData.fromJson(data.toJson());

    expect(decoded.latestFuelCheckIn?.guidanceValidFor, '2026-05-25');
    expect(decoded.latestFuelCheckIn?.score, 3);
    expect(
      decoded.latestFuelCheckIn?.context,
      'Restaurant meal before training.',
    );
    expect(decoded.toJson()['latestFuelCheckIn'], containsPair('score', 3));
  });

  test('FuelCheckIn migrates temporary rating values to score', () {
    final decoded = FuelCheckIn.fromJson({
      'guidanceValidFor': '2026-05-25',
      'rating': 'mostly',
      'context': 'Temporary older payload.',
      'createdAt': '2026-05-25T20:30:00',
    });

    expect(decoded.score, 8);
    expect(decoded.toJson(), isNot(contains('rating')));
  });

  test('coach context payloads include latest fuel check-in', () {
    final service = CoachPayloadService();
    final checkIn = FuelCheckIn(
      guidanceValidFor: '2026-05-25',
      score: 8,
      context: 'Had pasta but trained earlier than planned.',
      createdAt: DateTime(2026, 5, 25, 20, 30),
    );
    final data = sampleFitnessData().copyWith(latestFuelCheckIn: checkIn);
    const activity = DayActivityReport(
      summary: DayActivitySummary(
        readStatus: 'ok',
        missingPermissions: [],
        sampleCount: 0,
      ),
      sessions: [],
    );

    final snapshot = service.buildDailySnapshot(data);
    final dayContext = service.buildDayContext(
      data: data,
      activityReport: activity,
      day: DateTime(2026, 5, 25),
    );

    expect(snapshot['latestFuelCheckIn'], checkIn.toJson());
    expect(dayContext['latestFuelCheckIn'], checkIn.toJson());
  });
}
