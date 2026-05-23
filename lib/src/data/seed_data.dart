import '../models/fitness_models.dart';

FitnessData createEmptyFitnessData() {
  return FitnessData(
    profile: AthleteProfile(
      name: '',
      goal: '',
      heightCm: 0,
      weightKg: 0,
      age: 0,
      sex: 'unspecified',
      nutritionTarget: NutritionTarget(
        dailyCalories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        goalMode: 'Codex inferred',
        rationale: '',
        updatedAt: DateTime.now(),
        source: 'empty',
      ),
      trainingDays: 0,
      sessionMinutes: 0,
      equipment: const [],
      constraints: const [],
      preferences: const [],
    ),
    blocks: const [],
    activeBlockId: null,
    logs: const [],
    nutrition: const [],
    pendingMealRequest: null,
    pendingMealResult: null,
    coachDecisions: const [],
    memories: const [],
  );
}
