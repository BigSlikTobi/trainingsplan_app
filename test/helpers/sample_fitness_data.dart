import 'package:trainingsplan_app/src/data/seed_data.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';

/// Test fixture: an empty shell augmented with one planned block + workout
/// so tests can exercise next-workout / active-block flows without depending
/// on production seed data (which is now an empty shell filled by the agent).
FitnessData sampleFitnessData() {
  final empty = createEmptyFitnessData();
  const workout1 = PlannedWorkout(
    id: 'sample_w1_d1',
    week: 1,
    day: 1,
    title: 'W1 D1 - Sample A',
    focus: 'Sample focus A',
    rationale: 'Sample rationale A for test fixture.',
    conditioning: '10 min easy walk',
    exercises: [
      ExercisePrescription(
        exerciseId: 'goblet_squat',
        name: 'Goblet Squat',
        sets: 3,
        reps: '8-10',
        targetLoad: 'moderate',
        targetRpe: 7,
        restSeconds: 90,
        coachCue: 'Brace before each rep.',
      ),
    ],
  );
  const workout2 = PlannedWorkout(
    id: 'sample_w1_d2',
    week: 1,
    day: 2,
    title: 'W1 D2 - Sample B',
    focus: 'Sample focus B',
    rationale: 'Sample rationale B for test fixture.',
    conditioning: '10 min easy bike',
    exercises: [
      ExercisePrescription(
        exerciseId: 'romanian_deadlift',
        name: 'Romanian Deadlift',
        sets: 3,
        reps: '8-10',
        targetLoad: 'moderate',
        targetRpe: 7,
        restSeconds: 90,
        coachCue: 'Hinge from the hips.',
      ),
    ],
  );
  final block = TrainingBlock(
    id: 'sample_block',
    style: TrainingStyle.strengthHypertrophy,
    title: 'Sample Block',
    durationWeeks: 8,
    currentWeek: 1,
    weeklyFocus: const ['Sample weekly focus'],
    measurableTargets: const ['Sample target'],
    workouts: [workout1, workout2],
    createdBy: 'test',
    createdAt: DateTime(2026, 5, 18),
  );
  return empty.copyWith(
    profile: empty.profile.copyWith(
      name: 'Tobi',
      goal: 'Muscle + strength with athletic conditioning',
      heightCm: 182,
      weightKg: 82,
      age: 35,
      nutritionTarget: NutritionTarget(
        dailyCalories: 2600,
        protein: 170,
        carbs: 280,
        fat: 80,
        goalMode: 'T4L Gym Bro inferred recomposition',
        rationale: 'Test fixture target.',
        updatedAt: DateTime(2026, 5, 18),
        source: 'test',
      ),
      trainingDays: 4,
      sessionMinutes: 55,
      equipment: Equipment.values,
    ),
    blocks: [block],
    activeBlockId: block.id,
    nutrition: [
      NutritionLog(
        date: DateTime(2026, 5, 18),
        calories: 2600,
        protein: 170,
        carbs: 280,
        fat: 80,
        bodyWeightKg: 82,
        notes: 'Baseline.',
      ),
    ],
  );
}
