import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/app.dart';
import 'package:trainingsplan_app/src/data/local_store.dart';
import 'package:trainingsplan_app/src/l10n/app_localizations.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/health_sync_service.dart';
import 'package:trainingsplan_app/src/services/local_bridge_service.dart';
import 'package:trainingsplan_app/src/services/watch_sync_service.dart';
import 'package:trainingsplan_app/src/state/fitness_controller.dart';
import 'package:trainingsplan_app/src/ui/dashboard.dart';
import 'package:trainingsplan_app/src/ui/workout_summary_screen.dart';

import 'helpers/sample_fitness_data.dart';

void main() {
  testWidgets('shows coached fitness app navigation', (tester) async {
    await tester.pumpWidget(const T4LTrainerApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('nutrition page exposes T4L Gym Bro meal analysis flow', (
    tester,
  ) async {
    final controller = FitnessController(store: _WidgetStore());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Fuel').last);
    await tester.pumpAndSettle();

    expect(find.text('Fuel + Recovery'), findsWidgets);
  });

  testWidgets('setup page exposes agent handoff details', (tester) async {
    final controller = FitnessController(store: _WidgetStore());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Apple Health'), findsWidgets);
    expect(find.text('Nicht verbunden'), findsOneWidget);
    expect(find.text('IN ZWISCHENABLAGE KOPIEREN'), findsOneWidget);
    expect(find.text('VERBINDEN'), findsOneWidget);
  });

  testWidgets('coach hub shows block banner and segment tabs', (tester) async {
    final controller = FitnessController(store: _WidgetStore());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();

    expect(find.text('Sample Block'), findsOneWidget);
    expect(find.text('PLAN'), findsOneWidget);
    expect(find.text('MEMORY'), findsOneWidget);
    expect(find.text('SYNC'), findsOneWidget);
  });

  testWidgets('today workout rows keep long coaching text in details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = FitnessController(store: _WidgetStore(_longCoachData()));
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Goblet Squat With Deliberately Long Name'),
      findsOneWidget,
    );
    expect(find.textContaining('Keep the ribcage stacked'), findsOneWidget);
    expect(find.byTooltip('Erklärvideo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Goblet Squat With Deliberately Long Name'));
    await tester.pumpAndSettle();

    expect(find.text('AGENT NOTE'), findsOneWidget);
    expect(find.textContaining('This longer note belongs'), findsOneWidget);
    expect(find.byTooltip('Erklärvideo'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('today workout rows show exercise Apple Health metrics', (
    tester,
  ) async {
    final controller = FitnessController(
      store: _WidgetStore(_activeWorkoutWithExerciseHealthData()),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('132 bpm'), findsOneWidget);
    expect(find.text('18 kcal'), findsOneWidget);
  });

  testWidgets('progress tab shows weekly Apple Health charts', (tester) async {
    final controller = FitnessController(
      store: _WidgetStore(_progressHealthData()),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();

    expect(find.text('CALORIES BURNED'), findsOneWidget);
    expect(find.text('TRAINING HEART RATE'), findsOneWidget);
    expect(find.text('270 kcal'), findsWidgets);
    expect(find.text('128 bpm'), findsOneWidget);
  });

  testWidgets('today hero title uses workout title for daily coach plans', (
    tester,
  ) async {
    final controller = FitnessController(
      store: _WidgetStore(_dailyCoachPlanData()),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PUSH PULL RESET'), findsOneWidget);
    expect(find.text('DAILY COACH PLANS'), findsNothing);
  });

  testWidgets('today shows the finished workout after the session is done', (
    tester,
  ) async {
    final controller = FitnessController(
      store: _WidgetStore(_dataWithCompletedFirstWorkoutToday()),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    // A workout finished today shows its summary, not the next workout's
    // open/Start state ("don't make me train again").
    expect(find.byType(WorkoutSummaryView), findsOneWidget);
    expect(find.text('Sample focus B'), findsNothing);
  });

  testWidgets('today keeps the just-finished workout for set logging', (
    tester,
  ) async {
    // Fakes keep the completion path hermetic: the real day-context export
    // reads HealthKit, which never completes under the widget-test binding.
    final controller = FitnessController(
      store: _WidgetStore(),
      health: _FakeHealthSync(),
      watchSync: _NoopWatchSync(),
    );
    await controller.load();
    final block = controller.activeBlock!;
    // More than one workout means a next workout exists — so this proves the
    // Today view shows the finished workout's summary (log sets / comments)
    // instead of falling back to the next workout's "Start" state.
    expect(block.workouts.length, greaterThan(1));
    final finished = block.workouts.first;

    // Finish the workout live (watch completion path — no HealthKit needed).
    await controller.handleWatchWorkoutCompleted(
      _watchCompletionPayloadFor(finished),
    );
    expect(controller.justCompletedLog, isNotNull);
    expect(controller.nextWorkout, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(WorkoutSummaryView), findsOneWidget);
  });

  testWidgets('today shows completed workout summary when no workout is open', (
    tester,
  ) async {
    final controller = FitnessController(
      store: _WidgetStore(_dataWithCompletedBlock()),
    );
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(WorkoutSummaryView), findsOneWidget);
    expect(find.text('DEIN'), findsNothing);
    expect(find.text('ERSTER'), findsNothing);
    expect(find.text('TAG.'), findsNothing);
  });

  testWidgets(
    'completed summary hero uses workout title for daily coach plans',
    (tester) async {
      final controller = FitnessController(
        store: _WidgetStore(_completedDailyCoachPlanData()),
      );
      await controller.load();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: FitnessScope(
            controller: controller,
            child: const CoachDashboard(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(WorkoutSummaryView), findsOneWidget);
      expect(find.text('PUSH PULL RESET'), findsOneWidget);
      expect(find.text('DAILY COACH PLANS'), findsNothing);
    },
  );

  testWidgets('coach hub memory tab shows memories', (tester) async {
    final controller = FitnessController(store: _WidgetStore());
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: FitnessScope(
          controller: controller,
          child: const CoachDashboard(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();

    expect(find.text('PLAN'), findsOneWidget);
    expect(find.text('MEMORY'), findsOneWidget);

    await tester.tap(find.text('MEMORY'));
    await tester.pumpAndSettle();

    expect(find.text('+ Hinzufügen'), findsOneWidget);
  });
}

class _WidgetStore extends LocalFitnessStore {
  _WidgetStore([FitnessData? data]) : _data = data ?? sampleFitnessData();

  final FitnessData _data;
  LocalBridgeConfig bridgeConfig = const LocalBridgeConfig();

  @override
  Future<FitnessData> load() async => _data;

  @override
  Future<void> save(FitnessData data) async {}

  @override
  Future<LocalBridgeConfig> loadBridgeConfig() async => bridgeConfig;

  @override
  Future<void> saveBridgeConfig(LocalBridgeConfig config) async {
    bridgeConfig = config;
  }

  @override
  Future<bool> loadChatVoiceEnabled() async => true;

  @override
  Future<void> saveChatVoiceEnabled(bool enabled) async {}
}

class _FakeHealthSync extends HealthSyncService {
  @override
  Future<DayActivityReport> readDayActivityReport(DateTime day) async {
    return const DayActivityReport(
      summary: DayActivitySummary(
        readStatus: 'ok',
        missingPermissions: [],
        sampleCount: 0,
      ),
      sessions: [],
    );
  }
}

class _NoopWatchSync extends WatchSyncService {
  @override
  Stream<Map<String, dynamic>> get events =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Future<String> syncWorkout({
    required PlannedWorkout workout,
    WorkoutLog? activeLog,
    WorkoutLog? completedLog,
  }) async => 'noop';

  @override
  Future<void> markCompletionHandled(String completionId) async {}

  @override
  Future<void> endWatchWorkout(String workoutId) async {}
}

FitnessData _longCoachData() {
  final base = sampleFitnessData();
  final block = base.activeBlock!;
  final workout = block.workouts.first;
  const longExercise = ExercisePrescription(
    exerciseId: 'long_goblet_squat',
    name: 'Goblet Squat With Deliberately Long Name',
    sets: 4,
    reps: '8-10 controlled reps with tempo',
    targetLoad:
        'Ramp from a very conservative warm-up to the heaviest technically clean load available today without losing tempo or bracing.',
    loadLabel: '12-24 kg',
    targetRpe: 7.5,
    restSeconds: 105,
    coachCue:
        'Keep the ribcage stacked over the pelvis and breathe behind the brace before every rep.',
    primaryCue: 'Keep the ribcage stacked',
    detailNote:
        'This longer note belongs in the exercise detail sheet where the athlete can read setup, intent, and rationale without stretching the row.',
    warningCue:
        'Stop or reduce range immediately if knee pain increases during the set.',
    media: ExerciseMedia(
      explainerUrl: 'https://www.youtube.com/watch?v=abc123',
      setup:
          'Set the feet just outside hip width, hold the bell high against the sternum, and create a tripod foot before the first descent.',
      cues: [
        'Brace before the descent and keep the elbows inside the knees.',
        'Drive up evenly through the whole foot without shifting into the toes.',
      ],
      commonMistakes: [
        'Letting the heels float during the deepest part of the squat.',
        'Collapsing the knees inward when fatigue rises late in the set.',
      ],
    ),
  );
  final updatedWorkout = PlannedWorkout(
    id: workout.id,
    week: workout.week,
    day: workout.day,
    title: workout.title,
    focus: workout.focus,
    rationale:
        'A deliberately long rationale should stay out of the compact row and live in details or plan review.',
    exercises: [longExercise],
    conditioning: workout.conditioning,
  );
  final updatedBlock = TrainingBlock(
    id: block.id,
    style: block.style,
    title: block.title,
    durationWeeks: block.durationWeeks,
    currentWeek: block.currentWeek,
    weeklyFocus: block.weeklyFocus,
    measurableTargets: block.measurableTargets,
    workouts: [updatedWorkout, ...block.workouts.skip(1)],
    createdBy: block.createdBy,
    createdAt: block.createdAt,
  );
  return base.copyWith(blocks: [updatedBlock], activeBlockId: updatedBlock.id);
}

FitnessData _activeWorkoutWithExerciseHealthData() {
  final base = sampleFitnessData();
  final workout = base.activeBlock!.workouts.first;
  final exercise = workout.exercises.first;
  final startedAt = DateTime.now().subtract(const Duration(minutes: 12));
  final completedAt = DateTime.now().subtract(const Duration(minutes: 8));
  final activeLog = WorkoutLog(
    id: 'log-active-health',
    workoutId: workout.id,
    title: workout.title,
    startedAt: startedAt,
    completedAt: null,
    readiness: 3,
    soreness: 2,
    notes: '',
    sets: const [],
    healthWriteStatus: 'live_tracking',
    exerciseTimings: [
      ExerciseTiming(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        startedAt: startedAt,
        completedAt: completedAt,
        healthSnapshot: LiveHealthMetrics(
          updatedAt: completedAt,
          sampleCount: 3,
          heartRateBpm: 132,
          activeEnergyKcal: 18,
        ),
      ),
    ],
  );
  return base.copyWith(logs: [activeLog]);
}

FitnessData _progressHealthData() {
  final base = sampleFitnessData();
  final workout = base.activeBlock!.workouts.first;
  final now = DateTime.now();
  final logs = [
    _completedHealthLog(
      id: 'progress-health-this-week',
      workout: workout,
      startedAt: now.subtract(const Duration(days: 1, hours: 2)),
      calories: 270,
      heartRate: 128,
    ),
    _completedHealthLog(
      id: 'progress-health-last-week',
      workout: workout,
      startedAt: now.subtract(const Duration(days: 8, hours: 1)),
      calories: 220,
      heartRate: 122,
    ),
  ];
  return base.copyWith(logs: logs);
}

WorkoutLog _completedHealthLog({
  required String id,
  required PlannedWorkout workout,
  required DateTime startedAt,
  required double calories,
  required double heartRate,
}) {
  final completedAt = startedAt.add(const Duration(minutes: 50));
  return WorkoutLog(
    id: id,
    workoutId: workout.id,
    title: workout.title,
    startedAt: startedAt,
    completedAt: completedAt,
    readiness: 4,
    soreness: 2,
    notes: '',
    sets: const [],
    healthWriteStatus: 'matched_apple_health_workout',
    healthMetrics: LiveHealthMetrics(
      updatedAt: completedAt,
      sampleCount: 5,
      activeEnergyKcal: calories,
      heartRateBpm: heartRate,
    ),
  );
}

FitnessData _dataWithCompletedFirstWorkoutToday() {
  final base = sampleFitnessData();
  final firstWorkout = base.activeBlock!.workouts.first;
  final completed = WorkoutLog(
    id: 'log-completed-today',
    workoutId: firstWorkout.id,
    title: firstWorkout.title,
    startedAt: DateTime.now().subtract(const Duration(minutes: 45)),
    completedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    readiness: 3,
    soreness: 2,
    notes: '',
    sets: const [],
    healthWriteStatus: 'not_synced',
  );
  return base.copyWith(logs: [completed]);
}

Map<String, dynamic> _watchCompletionPayloadFor(PlannedWorkout workout) {
  final exercise = workout.exercises.first;
  final started = DateTime.now().subtract(const Duration(minutes: 40));
  final completed = DateTime.now().subtract(const Duration(minutes: 2));
  return {
    'schemaVersion': 1,
    'completionId': 'completion-${workout.id}',
    'workoutId': workout.id,
    'title': workout.title,
    'startedAt': started.toIso8601String(),
    'completedAt': completed.toIso8601String(),
    'pausedSeconds': 0,
    'healthWriteStatus': 'watch_health_synced',
    'sets': [
      {
        'exerciseId': exercise.exerciseId,
        'exerciseName': exercise.name,
        'setNumber': 1,
        'weightKg': 20,
        'reps': 8,
        'rpe': 7,
      },
    ],
    'exerciseTimings': [
      {
        'exerciseId': exercise.exerciseId,
        'exerciseName': exercise.name,
        'startedAt': started.toIso8601String(),
        'completedAt': completed.toIso8601String(),
        'pausedSeconds': 0,
      },
    ],
  };
}

FitnessData _dataWithCompletedBlock() {
  final base = sampleFitnessData();
  final logs = [
    for (final workout in base.activeBlock!.workouts)
      WorkoutLog(
        id: 'log-${workout.id}',
        workoutId: workout.id,
        title: workout.title,
        startedAt: DateTime.now().subtract(const Duration(minutes: 45)),
        completedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        readiness: 3,
        soreness: 2,
        notes: '',
        sets: const [],
        healthWriteStatus: 'not_synced',
      ),
  ];
  return base.copyWith(logs: logs);
}

FitnessData _dailyCoachPlanData() {
  final base = sampleFitnessData();
  final workout = base.activeBlock!.workouts.first;
  final dailyWorkout = PlannedWorkout(
    id: 'daily_push_pull_reset',
    week: 1,
    day: 1,
    title: 'Push Pull Reset',
    focus: workout.focus,
    rationale: workout.rationale,
    exercises: workout.exercises,
    conditioning: workout.conditioning,
  );
  final dailyBlock = TrainingBlock(
    id: 'block_daily',
    style: TrainingStyle.custom,
    title: 'Daily Coach Plans',
    durationWeeks: 1,
    currentWeek: 1,
    weeklyFocus: const ['Daily coach adjustment'],
    measurableTargets: const [],
    workouts: [dailyWorkout],
    createdBy: 'T4L server',
    createdAt: DateTime(2026, 5, 26),
  );
  return base.copyWith(blocks: [dailyBlock], activeBlockId: dailyBlock.id);
}

FitnessData _completedDailyCoachPlanData() {
  final data = _dailyCoachPlanData();
  final workout = data.activeBlock!.workouts.single;
  final completed = WorkoutLog(
    id: 'log-completed-daily',
    workoutId: workout.id,
    title: 'Daily Coach Plans',
    startedAt: DateTime.now().subtract(const Duration(minutes: 45)),
    completedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    readiness: 3,
    soreness: 2,
    notes: '',
    sets: const [],
    healthWriteStatus: 'not_synced',
  );
  return data.copyWith(logs: [completed]);
}
