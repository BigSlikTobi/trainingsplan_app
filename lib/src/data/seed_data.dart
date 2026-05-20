import '../models/fitness_models.dart';
import 'exercise_library.dart';

FitnessData createSeedFitnessData() {
  final block = createTemplateBlock(TrainingStyle.rugby);
  return FitnessData(
    profile: AthleteProfile(
      name: 'Tobi',
      goal: 'Muscle + strength with athletic conditioning',
      heightCm: 182,
      weightKg: 82,
      age: 35,
      sex: 'unspecified',
      nutritionTarget: NutritionTarget(
        dailyCalories: 2600,
        protein: 170,
        carbs: 280,
        fat: 80,
        goalMode: 'Codex inferred recomposition',
        rationale:
            'Initial target until Codex can refine from training and intake trends.',
        updatedAt: DateTime(2026, 5, 18),
        source: 'seed',
      ),
      trainingDays: 4,
      sessionMinutes: 55,
      equipment: Equipment.values,
      constraints: ['Train mostly at home', 'Prefer measurable progressions'],
      preferences: ['German coaching language', 'Codex explains every change'],
    ),
    blocks: [block],
    activeBlockId: block.id,
    logs: const [],
    nutrition: [
      NutritionLog(
        date: DateTime(2026, 5, 18),
        calories: 2600,
        protein: 170,
        carbs: 280,
        fat: 80,
        bodyWeightKg: 82,
        notes: 'Baseline targets for the first coached block.',
      ),
    ],
    pendingMealRequest: null,
    pendingMealResult: null,
    coachDecisions: [
      CoachDecision(
        id: 'decision_seed',
        createdAt: DateTime(2026, 5, 18, 21),
        title: 'Initial Codex coaching mode',
        rationale:
            'Use an 8-week athletic block, log every set, export daily snapshots, and let Codex adjust tomorrow based on performance, recovery, and nutrition.',
        safetyFlags: const [],
        accepted: true,
      ),
    ],
    memories: [
      MemoryEntry(
        id: 'memory_seed_goal',
        createdAt: DateTime(2026, 5, 18, 21),
        updatedAt: DateTime(2026, 5, 18, 21),
        category: MemoryCategory.goal,
        title: 'Primary training direction',
        summary:
            'Build muscle and strength while keeping athletic conditioning high.',
        markdown:
            'Use this as the default coaching context until the user replaces it with a more specific block goal.',
        source: 'seed',
        confidence: 0.85,
        active: true,
      ),
    ],
  );
}

TrainingBlock createTemplateBlock(TrainingStyle style) {
  final now = DateTime.now();
  final selected = _templateFor(style);
  return TrainingBlock(
    id: newId('block'),
    style: style,
    title: '8 Wochen ${style.label}',
    durationWeeks: 8,
    currentWeek: 1,
    weeklyFocus: selected.weeklyFocus,
    measurableTargets: selected.targets,
    workouts: _buildWorkouts(style),
    createdBy: 'Local template, ready for Codex refinement',
    createdAt: now,
  );
}

_Template _templateFor(TrainingStyle style) {
  return switch (style) {
    TrainingStyle.rugby => const _Template(
      weeklyFocus: [
        'Weeks 1-2: strength base and acceleration mechanics',
        'Weeks 3-4: heavier lower body and repeat sprint ability',
        'Weeks 5-6: power emphasis and high-quality conditioning',
        'Week 7: peak intensity with reduced junk volume',
        'Week 8: deload, tests, and Codex review',
      ],
      targets: [
        'Increase hinge and squat working weights',
        'Improve repeat sprint conditioning',
        'Keep shoulder and trunk robustness high',
      ],
    ),
    TrainingStyle.boxer => const _Template(
      weeklyFocus: [
        'Weeks 1-2: aerobic base, trunk rotation, shoulder capacity',
        'Weeks 3-4: intervals, unilateral legs, punch endurance',
        'Weeks 5-6: power endurance and footwork conditioning',
        'Week 7: sharp high-intensity sessions',
        'Week 8: deload and benchmark conditioning',
      ],
      targets: [
        'Improve conditioning without losing strength',
        'Build shoulder durability',
        'Increase rotational power and trunk stiffness',
      ],
    ),
    TrainingStyle.hybrid => const _Template(
      weeklyFocus: [
        'Weeks 1-2: movement quality and base volume',
        'Weeks 3-4: strength plus threshold conditioning',
        'Weeks 5-6: density and power',
        'Week 7: hard but controlled peak',
        'Week 8: deload and retest',
      ],
      targets: [
        'Four consistent sessions weekly',
        'Strength PR trend',
        'Conditioning compliance',
      ],
    ),
    TrainingStyle.strengthHypertrophy => const _Template(
      weeklyFocus: [
        'Weeks 1-2: volume base',
        'Weeks 3-4: progressive overload',
        'Weeks 5-6: intensity emphasis',
        'Week 7: top sets plus back-off work',
        'Week 8: deload and rep PRs',
      ],
      targets: [
        'More volume at same RPE',
        'Rep PRs on main lifts',
        'Stable bodyweight trend',
      ],
    ),
    TrainingStyle.conditioning => const _Template(
      weeklyFocus: [
        'Weeks 1-2: base circuits',
        'Weeks 3-4: density progressions',
        'Weeks 5-6: harder intervals',
        'Week 7: peak conditioning',
        'Week 8: deload and benchmark',
      ],
      targets: [
        'Higher work capacity',
        'Lower perceived exertion',
        'Consistent recovery',
      ],
    ),
    TrainingStyle.custom => const _Template(
      weeklyFocus: [
        'Codex should define phase goals from the block request',
        'Codex should adjust equipment and constraints',
        'Codex should produce measurable tests',
      ],
      targets: ['Defined by Codex after discussion'],
    ),
  };
}

List<PlannedWorkout> _buildWorkouts(TrainingStyle style) {
  final main = switch (style) {
    TrainingStyle.rugby => [
      'Lower Power',
      'Upper Strength',
      'Repeat Sprint Engine',
      'Full-Body Collision Prep',
    ],
    TrainingStyle.boxer => [
      'Rotational Strength',
      'Shoulder Engine',
      'Legs + Footwork',
      'Fight Conditioning',
    ],
    TrainingStyle.hybrid => [
      'Strength A',
      'Engine',
      'Strength B',
      'Athletic Circuit',
    ],
    TrainingStyle.strengthHypertrophy => [
      'Lower Strength',
      'Upper Push/Pull',
      'Lower Volume',
      'Upper Hypertrophy',
    ],
    TrainingStyle.conditioning => [
      'Strength Circuit',
      'Core + Carry',
      'Intervals',
      'Mobility Engine',
    ],
    TrainingStyle.custom => [
      'Codex Session A',
      'Codex Session B',
      'Codex Session C',
      'Codex Session D',
    ],
  };

  final exerciseSets = [
    [
      'goblet_squat',
      'romanian_deadlift',
      'band_pallof_press',
      'kettlebell_swing',
    ],
    ['dumbbell_floor_press', 'one_arm_row', 'military_press', 'band_face_pull'],
    [
      'bulgarian_split_squat',
      'kettlebell_swing',
      'bosu_plank',
      'band_pallof_press',
    ],
    [
      'romanian_deadlift',
      'dumbbell_floor_press',
      'turkish_get_up',
      'curl_bar_curl',
    ],
  ];

  final workouts = <PlannedWorkout>[];
  for (var week = 1; week <= 8; week++) {
    for (var day = 1; day <= 4; day++) {
      final ids = exerciseSets[day - 1];
      workouts.add(
        PlannedWorkout(
          id: 'w${week}_d${day}_${style.name}',
          week: week,
          day: day,
          title: 'W$week D$day - ${main[day - 1]}',
          focus: main[day - 1],
          rationale: _rationaleFor(style, week),
          exercises: ids.map((id) {
            final exercise = exerciseById(id)!;
            final isMain = ids.indexOf(id) < 2;
            return ExercisePrescription(
              exerciseId: exercise.id,
              name: exercise.name,
              sets: week == 8 ? 2 : (isMain ? 4 : 3),
              reps: isMain ? (week > 4 ? '5-8' : '8-10') : '10-15',
              targetLoad: isMain
                  ? 'RPE ${(6.5 + week * .25).clamp(6.5, 8.5).toStringAsFixed(1)}'
                  : 'Controlled',
              targetRpe: (6.5 + week * .25).clamp(6.5, 8.5),
              restSeconds: isMain ? 120 : 75,
              coachCue: exercise.media.cues.first,
              media: exercise.media,
            );
          }).toList(),
          conditioning: _conditioningFor(style, week),
        ),
      );
    }
  }
  return workouts;
}

String _rationaleFor(TrainingStyle style, int week) {
  if (week == 8) return 'Deload and collect benchmark data for Codex review.';
  return switch (style) {
    TrainingStyle.rugby =>
      'Build force production and repeat efforts without losing movement quality.',
    TrainingStyle.boxer =>
      'Keep strength useful, rotational, and fatigue-resistant.',
    TrainingStyle.hybrid =>
      'Balance strength exposure with conditioning that does not crush recovery.',
    TrainingStyle.strengthHypertrophy =>
      'Progress load or reps while keeping RPE honest.',
    TrainingStyle.conditioning =>
      'Increase density while protecting joints and technique.',
    TrainingStyle.custom => 'Placeholder until Codex imports the final block.',
  };
}

String _conditioningFor(TrainingStyle style, int week) {
  final minutes = week == 8 ? 8 : 10 + week;
  return switch (style) {
    TrainingStyle.rugby =>
      '$minutes min: 20s hard kettlebell swings / 70s easy walk',
    TrainingStyle.boxer =>
      '$minutes min: 3 min shadow-box footwork / 1 min nasal recovery',
    TrainingStyle.hybrid =>
      '$minutes min zone-2 finisher or loaded carry intervals',
    TrainingStyle.strengthHypertrophy =>
      '$minutes min easy incline walk or mobility flush',
    TrainingStyle.conditioning =>
      '$minutes min EMOM alternating swings, rows, planks',
    TrainingStyle.custom => 'Codex defines conditioning after block discussion',
  };
}

class _Template {
  const _Template({required this.weeklyFocus, required this.targets});

  final List<String> weeklyFocus;
  final List<String> targets;
}
