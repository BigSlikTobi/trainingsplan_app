import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainingsplan_app/src/app.dart';
import 'package:trainingsplan_app/src/data/local_store.dart';
import 'package:trainingsplan_app/src/l10n/app_localizations.dart';
import 'package:trainingsplan_app/src/models/fitness_models.dart';
import 'package:trainingsplan_app/src/services/local_bridge_service.dart';
import 'package:trainingsplan_app/src/state/fitness_controller.dart';
import 'package:trainingsplan_app/src/ui/dashboard.dart';

import 'helpers/sample_fitness_data.dart';

void main() {
  testWidgets('shows coached fitness app navigation', (tester) async {
    await tester.pumpWidget(const CodexCoachApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('nutrition page exposes Codex meal analysis flow', (
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

    await tester.tap(find.text('Fuel'));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Mahlzeit analysieren'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Mahlzeit analysieren'), findsOneWidget);
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

    expect(find.text('Agent Setup'), findsOneWidget);
    expect(find.text('Self-Hosted T4L Server'), findsOneWidget);
    expect(find.text('Migrate Data'), findsOneWidget);
    expect(find.text('Push Context'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Complete Agent Handoff'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Complete Agent Handoff'), findsOneWidget);
    expect(find.textContaining('CodexFitnessExchange'), findsWidgets);
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
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Goblet Squat With Deliberately Long Name'));
    await tester.pumpAndSettle();

    expect(find.text('AGENT NOTE'), findsOneWidget);
    expect(find.textContaining('This longer note belongs'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('coach tab prioritizes setup memory and plan review', (
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

    await tester.tap(find.text('Coach'));
    await tester.pumpAndSettle();

    expect(find.text('Coach'), findsWidgets);
    expect(find.text('Plan Review'), findsOneWidget);
    expect(find.text('Memory Wiki'), findsOneWidget);
    expect(find.text('Goblet Squat'), findsNothing);
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
  Future<File> writeExchangeJson(
    String fileName,
    Map<String, dynamic> payload,
  ) async {
    return File(fileName);
  }

  @override
  Future<bool> exchangeJsonExists(String fileName) async => false;

  @override
  Future<Directory> getExchangeDirectory() async {
    return Directory('/tmp/CodexFitnessExchange');
  }
}

FitnessData _longCoachData() {
  final base = sampleFitnessData();
  final block = base.activeBlock!;
  final workout = block.workouts.first;
  final longExercise = ExercisePrescription(
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
    media: const ExerciseMedia(
      explainerUrl: '',
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
