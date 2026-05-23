import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';

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

  test('workout log serializes health metrics for Codex snapshots', () {
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
        goalMode: 'Codex inferred recomposition',
        rationale: 'Recent training volume is high.',
        updatedAt: DateTime(2026, 5, 19, 13),
        source: 'Codex',
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
                'setup': 'Kettlebell tight to sternum.',
                'cues': ['Tripod foot', 'Brace hard'],
                'commonMistakes': ['Losing heel pressure'],
              },
            },
          ],
        },
      ],
      'createdBy': 'Codex',
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
    expect(block.workouts.single.exercises.single.media?.cues, [
      'Tripod foot',
      'Brace hard',
    ]);
    expect(block.workouts.single.exercises.single.media?.commonMistakes, [
      'Losing heel pressure',
    ]);
  });

  test('exercise prescription accepts flat Codex cue fields', () {
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
    expect(decoded.yesterdayRead, 'Solide Basis — passt zum heutigen Krafttraining.');
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
  });}
