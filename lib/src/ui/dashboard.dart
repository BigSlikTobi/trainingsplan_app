import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import '../design/design_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/fitness_models.dart';
import '../services/local_bridge_service.dart';
import 'set_log_modal.dart';
import 'today_hero_card.dart';
import 'workout_summary_screen.dart';

const _agentInstructionsRepo =
    'https://github.com/BigSlikTobi/t4l-agent-instructions';
const _bridgeInstallCommand = 'pipx install t4l-server';
const _bridgeServeCommand = 't4l-server serve --data-dir ~/T4LServerData';

class CoachDashboard extends StatefulWidget {
  const CoachDashboard({super.key});

  @override
  State<CoachDashboard> createState() => _CoachDashboardState();
}

class _CoachDashboardState extends State<CoachDashboard> {
  var index = 0;
  String? _seenJustCompletedLogId;

  @override
  Widget build(BuildContext context) {
    final controller = FitnessScope.of(context);
    final l = AppLocalizations.of(context)!;
    // When a workout has just been auto-closed, jump back to the Today
    // tab so the user lands on the inline summary. We track the id locally
    // so this fires once per completion — we no longer clear the controller's
    // _justCompletedLog here, because the watch sync relies on it to keep
    // showing the "Done" card instead of advancing to the next workout.
    final justCompleted = controller.justCompletedLog;
    if (justCompleted != null && _seenJustCompletedLogId != justCompleted.id) {
      _seenJustCompletedLogId = justCompleted.id;
      if (index != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => index = 0);
        });
      }
    }
    final pages = [
      _TodayPage(controller: controller),
      _CoachPage(controller: controller),
      _NutritionPage(controller: controller),
      _ProgressPage(controller: controller),
    ];
    final titles = [
      l.navHeute,
      l.navCoach,
      l.nutritionHeaderTitle,
      l.navProgress,
    ];
    if (index >= pages.length) index = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[index],
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: l.tooltipSettings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FitnessScope(
                  controller: controller,
                  child: const _SettingsScreen(),
                ),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  if (controller.status.trim().isNotEmpty)
                    _StatusBar(text: controller.status),
                  if (controller.hasPendingCoachBlock)
                    _CoachBlockAvailableBanner(controller: controller),
                  Expanded(
                    child: IndexedStack(index: index, children: pages),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          return NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            destinations: [
              NavigationDestination(
                icon: const Icon(CupertinoIcons.today),
                label: l.navHeute,
              ),
              NavigationDestination(
                icon: const Icon(CupertinoIcons.sparkles),
                label: l.navCoach,
              ),
              NavigationDestination(
                icon: const Icon(CupertinoIcons.chart_pie),
                label: l.navErnaehrung,
              ),
              NavigationDestination(
                icon: const Icon(CupertinoIcons.chart_bar),
                label: l.navProgress,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    final controller = FitnessScope.of(context);
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.navSetup,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(child: _SettingsPage(controller: controller)),
    );
  }
}

class _TodayPage extends StatelessWidget {
  const _TodayPage({required this.controller});

  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    final workout = controller.nextWorkout as PlannedWorkout?;
    final block = controller.activeBlock as TrainingBlock?;
    final data = controller.data as FitnessData;
    if (workout == null || block == null) {
      final completedLog = _latestCompletedWorkoutLog(data);
      if (completedLog != null) {
        return ColoredBox(
          color: AppColors.bg,
          child: WorkoutSummaryView(logId: completedLog.id),
        );
      }
      return _TodayEmptyState(controller: controller);
    }

    final completedInBlock = data.logs
        .where(
          (log) =>
              log.completedAt != null &&
              block.workouts.any((item) => item.id == log.workoutId),
        )
        .length;
    final progress = block.workouts.isEmpty
        ? 0.0
        : completedInBlock / block.workouts.length;
    final progressPercent = (progress * 100).round();
    final activeLog = controller.activeWorkoutLog as WorkoutLog?;
    final hasActiveWorkout = activeLog != null;
    final sessionIsPaused = controller.sessionIsPaused as bool;

    final totalSets = workout.exercises.fold<int>(
      0,
      (sum, ex) => sum + ex.sets,
    );
    final completedSets = activeLog?.sets.length ?? 0;
    final avgRpe = activeLog == null || activeLog.sets.isEmpty
        ? null
        : activeLog.sets.fold<double>(0, (s, set) => s + set.rpe) /
              activeLog.sets.length;

    // Find which exercise the hero should focus on: prefer running,
    // otherwise the first paused one.
    ExercisePrescription? focusedExercise;
    int focusedIndex = 0;
    bool focusedIsPaused = false;
    for (var i = 0; i < workout.exercises.length; i++) {
      final ex = workout.exercises[i];
      if (controller.isExerciseRunning(ex.exerciseId) as bool) {
        focusedExercise = ex;
        focusedIndex = i + 1;
        focusedIsPaused = false;
        break;
      }
    }
    if (focusedExercise == null) {
      for (var i = 0; i < workout.exercises.length; i++) {
        final ex = workout.exercises[i];
        if (controller.isExercisePaused(ex.exerciseId) as bool) {
          focusedExercise = ex;
          focusedIndex = i + 1;
          focusedIsPaused = true;
          break;
        }
      }
    }

    final heroStatus = !hasActiveWorkout
        ? HeroWorkoutStatus.bereit
        : sessionIsPaused
        ? HeroWorkoutStatus.pause
        : HeroWorkoutStatus.aktiv;

    final dayIndex = block.workouts.indexWhere((w) => w.id == workout.id);

    return ColoredBox(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        children: [
          _TodayDateLine(text: _formatToday(context)),
          const SizedBox(height: AppSpacing.medium),
          TodayHeroCard(
            status: heroStatus,
            block: block,
            workout: workout,
            dayIndex: dayIndex < 0 ? 1 : dayIndex + 1,
            totalDays: block.workouts.isEmpty ? 1 : block.workouts.length,
            sessionMinutes: data.profile.sessionMinutes,
            totalSets: totalSets,
            completedSets: completedSets,
            blockProgressPercent: progressPercent,
            sessionElapsed: controller.activeSessionElapsed as Duration?,
            avgRpe: avgRpe,
            focusedExercise: focusedExercise,
            focusedExerciseIndex: focusedIndex,
            focusedExerciseElapsed: focusedExercise == null
                ? null
                : controller.elapsedForExercise(focusedExercise.exerciseId)
                      as Duration?,
            focusedExerciseIsPaused: focusedIsPaused,
            canDismissFocus: focusedIsPaused,
            totalExercises: workout.exercises.length,
            onStart: controller.startCurrentWorkout,
            onComplete: () => controller.completeCurrentWorkout(),
            onPause: controller.pauseCurrentWorkout,
            onResume: controller.resumeCurrentWorkout,
            onStop: () => controller.stopCurrentWorkout(),
            onExercisePause: focusedExercise == null
                ? () {}
                : () => controller.pauseExerciseTimer(
                    focusedExercise!.exerciseId,
                  ),
            onExerciseResume: focusedExercise == null
                ? () {}
                : () => controller.resumeExerciseTimer(
                    focusedExercise!.exerciseId,
                  ),
            onExerciseStop: focusedExercise == null
                ? () {}
                : () => _handleExerciseStop(
                    context,
                    controller,
                    focusedExercise!,
                  ),
            dailyMotto: data.dailyMotto,
            onDismissExerciseFocus: () {
              if (focusedExercise != null && focusedIsPaused) {
                // Soft dismissal: explicit user pause already happened; this
                // is just a UI affordance to peek at the overview. We model
                // it by clearing focus via stopping no timer — the next
                // rebuild will re-evaluate. For now this is a no-op since
                // the focus is derived from controller state.
              }
            },
          ),
          const SizedBox(height: AppSpacing.page),
          _SectionLabel(label: AppLocalizations.of(context)!.sectionUebungen),
          const SizedBox(height: 6),
          const _RpeLegend(),
          const SizedBox(height: 8),
          _ExerciseListCard(
            workout: workout,
            exercises: workout.exercises,
            controller: controller,
            hasActiveWorkout: hasActiveWorkout,
            focusedExerciseId: focusedExercise?.exerciseId,
          ),
          if (workout.conditioning.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _ConditioningNote(text: workout.conditioning),
          ],
          if (workout.rationale.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.page),
            _CoachNote(text: workout.rationale),
          ],
        ],
      ),
    );
  }

  static WorkoutLog? _latestCompletedWorkoutLog(FitnessData data) {
    WorkoutLog? latest;
    for (final log in data.logs) {
      if (log.completedAt == null) continue;
      if (latest == null || log.completedAt!.isAfter(latest.completedAt!)) {
        latest = log;
      }
    }
    return latest;
  }

  static String _formatToday(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final now = DateTime.now();
    return DateFormat('EEE, d. MMM', locale).format(now);
  }
}

class _TodayDateLine extends StatelessWidget {
  const _TodayDateLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.paper.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _RpeLegend extends StatelessWidget {
  const _RpeLegend();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _RpeLegendDot(label: l.rpeLegendWarmup, color: AppColors.sage),
          const SizedBox(width: 14),
          _RpeLegendDot(label: l.rpeLegendModerat, color: AppColors.gold),
          const SizedBox(width: 14),
          _RpeLegendDot(label: l.rpeLegendHart, color: AppColors.coral),
        ],
      ),
    );
  }
}

class _RpeLegendDot extends StatelessWidget {
  const _RpeLegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: AppColors.paper.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class _ExerciseListCard extends StatelessWidget {
  const _ExerciseListCard({
    required this.workout,
    required this.exercises,
    required this.controller,
    required this.hasActiveWorkout,
    required this.focusedExerciseId,
  });

  final PlannedWorkout workout;
  final List<ExercisePrescription> exercises;
  final dynamic controller;
  final bool hasActiveWorkout;
  final String? focusedExerciseId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.paper.withValues(alpha: AppOpacity.hairline),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (var i = 0; i < exercises.length; i++)
              _buildExerciseRow(context, i),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseRow(BuildContext context, int i) {
    final exercise = exercises[i];
    final timing =
        controller.timingForExercise(exercise.exerciseId) as ExerciseTiming?;
    final isRunning = controller.isExerciseRunning(exercise.exerciseId) as bool;
    final isPaused = controller.isExercisePaused(exercise.exerciseId) as bool;
    final isStopped = controller.isExerciseStopped(exercise.exerciseId) as bool;
    final durationSeconds = timing?.durationSeconds;
    final elapsed = isStopped && durationSeconds != null
        ? Duration(seconds: durationSeconds)
        : controller.elapsedForExercise(exercise.exerciseId) as Duration?;
    final liveMetrics = controller.liveHealthMetrics as LiveHealthMetrics?;
    final healthMetrics = isStopped
        ? timing?.healthSnapshot
        : (isRunning || isPaused ? liveMetrics : null);

    return _ExerciseRow(
      number: i + 1,
      exercise: exercise,
      isLast: i == exercises.length - 1,
      hasActiveWorkout: hasActiveWorkout,
      isFocused: focusedExerciseId == exercise.exerciseId,
      isRunning: isRunning,
      isPaused: isPaused,
      isStopped: isStopped,
      elapsed: elapsed,
      healthMetrics: healthMetrics,
      onStart: () => controller.startExerciseTimer(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
      ),
      onPause: () => controller.pauseExerciseTimer(exercise.exerciseId),
      onResume: () => controller.resumeExerciseTimer(exercise.exerciseId),
      onStop: () => _handleExerciseStop(context, controller, exercise),
      onTap: () =>
          _showExerciseDetailSheet(context, controller, workout, exercise),
    );
  }
}

class _ConditioningNote extends StatelessWidget {
  const _ConditioningNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.schedule, size: 16, color: AppColors.sage),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.conditioningLabel,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                    color: AppColors.sage,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: AppColors.paper.withValues(alpha: 0.48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showExerciseDetailSheet(
  BuildContext context,
  dynamic controller,
  PlannedWorkout workout,
  ExercisePrescription exercise,
) async {
  final media = exercise.media;
  final setup = media?.setup.trim() ?? '';
  final cues = [
    if (exercise.displayPrimaryCue.isNotEmpty) exercise.displayPrimaryCue,
    ...?media?.cues.where((item) => item.trim().isNotEmpty),
  ];
  final mistakes =
      media?.commonMistakes.where((item) => item.trim().isNotEmpty).toList() ??
      const <String>[];
  final warning = exercise.displayWarningCue;
  final detailNote = exercise.displayDetailNote;
  final videoUri = _exerciseVideoUri(exercise);
  final restLabel = _restLabel(exercise.restSeconds);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    builder: (sheetContext) {
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.42,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            final l = AppLocalizations.of(context)!;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: AppColors.paper,
                        ),
                      ),
                    ),
                    if (videoUri != null) ...[
                      const SizedBox(width: 10),
                      _ExerciseVideoButton(uri: videoUri, prominent: true),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _ExerciseMetaChip(
                      text: '${exercise.sets} × ${exercise.reps}',
                      maxWidth: 120,
                    ),
                    if (exercise.displayLoadLabel.isNotEmpty)
                      _ExerciseMetaChip(
                        text: exercise.displayLoadLabel,
                        maxWidth: 120,
                      ),
                    _ExerciseMetaChip(
                      text: 'RPE ${_rpeText(exercise.targetRpe)}',
                      maxWidth: 90,
                    ),
                    if (restLabel != null)
                      _ExerciseMetaChip(text: restLabel, muted: true),
                  ],
                ),
                if (warning.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DetailCallout(
                    icon: CupertinoIcons.exclamationmark_triangle,
                    color: AppColors.coral,
                    text: warning,
                  ),
                ],
                if (exercise.coachCue.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DetailSection(
                    title: 'Coach Cue',
                    child: Text(
                      exercise.coachCue.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        fontStyle: FontStyle.italic,
                        color: AppColors.sage,
                      ),
                    ),
                  ),
                ],
                if (detailNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(title: 'Agent Note', child: Text(detailNote)),
                ],
                if (setup.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(title: 'Setup', child: Text(setup)),
                ],
                if (cues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: 'Cues',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final cue in cues)
                          _DetailBullet(
                            text: cue.trim(),
                            color: AppColors.sage,
                          ),
                      ],
                    ),
                  ),
                ],
                if (mistakes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: l.fehlerVermeiden,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final mistake in mistakes)
                          _DetailBullet(
                            text: mistake.trim(),
                            color: AppColors.coral,
                          ),
                      ],
                    ),
                  ),
                ],
                if (exercise.targetLoad.trim().isNotEmpty &&
                    exercise.targetLoad.trim() !=
                        exercise.displayLoadLabel) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: 'Load',
                    child: Text(exercise.targetLoad.trim()),
                  ),
                ],
                if (workout.rationale.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _DetailSection(
                    title: 'Rationale',
                    child: Text(workout.rationale.trim()),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showSetDialog(context, controller, exercise);
                        },
                        icon: const Icon(CupertinoIcons.plus_circle),
                        label: Text(l.btnSatzLoggen),
                      ),
                    ),
                    if (videoUri != null) ...[
                      const SizedBox(width: 10),
                      _VideoPill(onTap: () => _openExerciseVideo(videoUri)),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.paper.withValues(alpha: AppOpacity.hairline),
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 13,
          height: 1.45,
          color: AppColors.paper.withValues(alpha: 0.70),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: AppColors.paper.withValues(alpha: 0.28),
              ),
            ),
            const SizedBox(height: 7),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailCallout extends StatelessWidget {
  const _DetailCallout({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBullet extends StatelessWidget {
  const _DetailBullet({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(CupertinoIcons.check_mark, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.paper.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.number,
    required this.exercise,
    required this.isLast,
    required this.onTap,
    this.hasActiveWorkout = false,
    this.isFocused = false,
    this.isRunning = false,
    this.isPaused = false,
    this.isStopped = false,
    this.elapsed,
    this.healthMetrics,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onStop,
  });

  final int number;
  final ExercisePrescription exercise;
  final bool isLast;
  final VoidCallback onTap;
  final bool hasActiveWorkout;
  final bool isFocused;
  final bool isRunning;
  final bool isPaused;
  final bool isStopped;
  final Duration? elapsed;
  final LiveHealthMetrics? healthMetrics;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final loadLabel = exercise.displayLoadLabel;
    final cue = exercise.displayPrimaryCue;
    final restLabel = _restLabel(exercise.restSeconds);
    final rpeText = _rpeText(exercise.targetRpe);
    final videoUri = _exerciseVideoUri(exercise);
    final showRpeDot =
        !hasActiveWorkout || (!isRunning && !isPaused && !isStopped);
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: isFocused
              ? AppColors.sage.withValues(alpha: 0.05)
              : AppColors.transparent,
          border: Border(
            left: BorderSide(
              color: isFocused ? AppColors.sage : AppColors.transparent,
              width: 3,
            ),
            bottom: BorderSide(
              color: isLast
                  ? AppColors.transparent
                  : AppColors.paper.withValues(alpha: AppOpacity.hairline),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 16,
              child: Text(
                '$number',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.sage,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: isFocused ? AppColors.sage : AppColors.paper,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _ExerciseMetaChip(
                        text: '${exercise.sets} × ${exercise.reps}',
                      ),
                      if (loadLabel.isNotEmpty)
                        _ExerciseMetaChip(text: loadLabel, maxWidth: 96),
                      _ExerciseMetaChip(text: 'RPE $rpeText'),
                      if (restLabel != null)
                        _ExerciseMetaChip(text: restLabel, muted: true),
                    ],
                  ),
                  if (cue.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      cue,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sage,
                      ),
                    ),
                  ],
                  if (healthMetrics?.hasAnyValue ?? false) ...[
                    const SizedBox(height: 8),
                    _ExerciseHealthSummary(metrics: healthMetrics!),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (showRpeDot) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _rpeColor(exercise.targetRpe).withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (videoUri != null) ...[
              _ExerciseVideoButton(uri: videoUri),
              const SizedBox(width: 6),
            ],
            _ExerciseTimerControls(
              hasActiveWorkout: hasActiveWorkout,
              isRunning: isRunning,
              isPaused: isPaused,
              isStopped: isStopped,
              elapsed: elapsed,
              onStart: onStart,
              onPause: onPause,
              onResume: onResume,
              onStop: onStop,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseHealthSummary extends StatelessWidget {
  const _ExerciseHealthSummary({required this.metrics});

  final LiveHealthMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (metrics.heartRateBpm != null)
        _HealthMetricChip(
          icon: CupertinoIcons.heart_fill,
          text: '${_fmtMetric(metrics.heartRateBpm!)} bpm',
          color: AppColors.coral,
        ),
      if (metrics.activeEnergyKcal != null)
        _HealthMetricChip(
          icon: CupertinoIcons.flame_fill,
          text: '${_fmtMetric(metrics.activeEnergyKcal!)} kcal',
          color: AppColors.gold,
        ),
      if (metrics.steps != null)
        _HealthMetricChip(
          icon: Icons.directions_walk,
          text: '${metrics.steps} steps',
          color: AppColors.sage,
        ),
      if (metrics.bloodOxygenPercent != null)
        _HealthMetricChip(
          icon: Icons.water_drop,
          text: '${_fmtMetric(metrics.bloodOxygenPercent!)}%',
          color: AppColors.sage,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 5, children: chips);
  }
}

class _HealthMetricChip extends StatelessWidget {
  const _HealthMetricChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w800,
              color: AppColors.paper.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseMetaChip extends StatelessWidget {
  const _ExerciseMetaChip({
    required this.text,
    this.maxWidth,
    this.muted = false,
  });

  final String text;
  final double? maxWidth;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: muted
            ? AppColors.paper.withValues(alpha: 0.04)
            : AppColors.sage.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: muted
              ? AppColors.paper.withValues(alpha: 0.08)
              : AppColors.sage.withValues(alpha: 0.17),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w800,
          color: muted
              ? AppColors.paper.withValues(alpha: 0.42)
              : AppColors.paper.withValues(alpha: 0.70),
        ),
      ),
    );
  }
}

class _ExerciseVideoButton extends StatelessWidget {
  const _ExerciseVideoButton({required this.uri, this.prominent = false});

  final Uri uri;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context)!.erklaervideo;
    final size = prominent ? 38.0 : 32.0;
    return Tooltip(
      message: label,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () => _openExerciseVideo(uri),
          borderRadius: BorderRadius.circular(99),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: prominent ? 0.13 : 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.28)),
            ),
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.play_fill,
              size: prominent ? 15 : 12,
              color: AppColors.sage,
            ),
          ),
        ),
      ),
    );
  }
}

Color _rpeColor(double rpe) {
  if (rpe <= 4) return AppColors.sage;
  if (rpe <= 6) return AppColors.gold;
  return AppColors.coral;
}

String _rpeText(double rpe) => rpe == rpe.roundToDouble()
    ? rpe.toStringAsFixed(0)
    : rpe.toStringAsFixed(1);

String _fmtMetric(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

String? _restLabel(int seconds) {
  if (seconds <= 0) return null;
  if (seconds >= 60 && seconds % 60 == 0) return '${seconds ~/ 60} min';
  if (seconds >= 60) return '${(seconds / 60).toStringAsFixed(1)} min';
  return '${seconds}s';
}

class _ExerciseTimerControls extends StatelessWidget {
  const _ExerciseTimerControls({
    required this.hasActiveWorkout,
    required this.isRunning,
    required this.isPaused,
    required this.isStopped,
    required this.elapsed,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final bool hasActiveWorkout;
  final bool isRunning;
  final bool isPaused;
  final bool isStopped;
  final Duration? elapsed;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    if (!hasActiveWorkout) {
      return Icon(
        Icons.chevron_right,
        size: 22,
        color: AppColors.paper.withValues(alpha: 0.17),
      );
    }
    if (isStopped) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (elapsed != null) ...[
            Text(
              _fmtElapsed(elapsed!),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.sage,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, size: 14, color: AppColors.sage),
          ),
        ],
      );
    }

    if (!isRunning && !isPaused) {
      // Idle in active workout: prominent 40px circular sage play button.
      return _CircularPlayButton(onTap: onStart);
    }

    final timerColor = isRunning ? AppColors.coral : AppColors.gold;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (elapsed != null)
          Padding(
            padding: const EdgeInsets.only(right: 7),
            child: SizedBox(
              width: 42,
              child: Text(
                _fmtElapsed(elapsed!),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: timerColor,
                  letterSpacing: 0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        _SquareTimerButton(
          icon: isPaused ? Icons.play_arrow : Icons.pause,
          iconColor: isPaused ? AppColors.sage : AppColors.paper,
          background: AppColors.surface3,
          onTap: isPaused ? onResume : onPause,
        ),
        const SizedBox(width: 6),
        _SquareTimerButton(
          icon: Icons.stop,
          iconColor: AppColors.coral,
          background: AppColors.coral.withValues(alpha: 0.10),
          onTap: onStop,
        ),
      ],
    );
  }
}

class _CircularPlayButton extends StatelessWidget {
  const _CircularPlayButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.13),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.sage.withValues(alpha: 0.28),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.play_arrow, size: 18, color: AppColors.sage),
        ),
      ),
    );
  }
}

class _SquareTimerButton extends StatelessWidget {
  const _SquareTimerButton({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}

String _fmtElapsed(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

class _CoachNote extends StatelessWidget {
  const _CoachNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.sage, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) => Text(
              AppLocalizations.of(context)!.labelCoach,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: AppColors.sage,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: AppColors.paper.withValues(alpha: 0.48),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayEmptyState extends StatelessWidget {
  const _TodayEmptyState({required this.controller});

  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    final isConnected =
        (controller.bridgeConfig as LocalBridgeConfig).isConfigured;
    final block = controller.activeBlock as TrainingBlock?;
    final hasBlockPlans = block != null && block.workouts.isNotEmpty;
    return ColoredBox(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        children: [
          _TodayDateLine(text: _TodayPage._formatToday(context)),
          const SizedBox(height: AppSpacing.medium),
          if (hasBlockPlans)
            _CompletedBlockHeroCard(block: block)
          else
            EmptyHeroCard(
              isConnected: isConnected,
              onLoadPlan: controller.importCoachBlockPlan,
              onConnect: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FitnessScope(
                    controller: controller,
                    child: const _SettingsScreen(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.page),
          _SectionLabel(label: AppLocalizations.of(context)!.sectionUebungen),
          const SizedBox(height: AppSpacing.small),
          const GhostExerciseSection(),
          const SizedBox(height: 14),
          Center(
            child: Text(
              hasBlockPlans
                  ? AppLocalizations.of(context)!.emptyAlleWorkoutsErledigt
                  : AppLocalizations.of(context)!.emptyPlanErscheintHier,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.4,
                color: AppColors.paper.withValues(alpha: 0.28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedBlockHeroCard extends StatelessWidget {
  const _CompletedBlockHeroCard({required this.block});

  final TrainingBlock block;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: AppColors.sage),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.blockAbgeschlossen,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              block.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(
                context,
              )!.blockAbgeschlossenInfo(block.workouts.length),
              style: TextStyle(color: AppColors.paper.withValues(alpha: 0.52)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

  final double radius;
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength > metric.length
            ? metric.length
            : distance + dashLength;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}

class _NutritionPage extends StatelessWidget {
  const _NutritionPage({required this.controller});

  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data as FitnessData;
    final profile = data.profile;
    final target = profile.nutritionTarget;
    final workout = controller.nextWorkout as PlannedWorkout?;
    final latest = data.nutrition.isEmpty ? null : data.nutrition.first;
    final guidance = controller.fuelGuidance as FuelGuidance?;
    final today = _todayDateKey();
    final isGuidanceFresh = guidance != null && guidance.validFor == today;

    return ColoredBox(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
        children: [
          _NutritionHeader(
            week: workout?.week,
            day: workout?.day,
            onEditProfile: () =>
                _showProfileDialog(context, controller, profile),
          ),
          const SizedBox(height: 10),
          if (!isGuidanceFresh) ...[
            _NoGuidancePlaceholder(isStale: guidance != null),
          ] else ...[
            _SignalBadge(signal: guidance.signal),
            const SizedBox(height: 10),
            _FuelAdviceCard(
              day: workout?.title ?? '',
              text: guidance.todayAdvice,
              mealName: guidance.mealSuggestion.name,
              mealRationale: guidance.mealSuggestion.rationale,
            ),
          ],
          const SizedBox(height: 10),
          _FuelDiaryCard(
            entries: controller.todayFuelDiary,
            sentToday: controller.fuelDiarySentToday,
            onAdd: (text) => controller.addFuelDiaryEntry(text),
            onRemove: (id) => controller.removeFuelDiaryEntry(id),
            onSend: (score) => controller.submitFuelDiary(score: score),
          ),
          if (isGuidanceFresh) ...[
            const SizedBox(height: 10),
            _YesterdayCard(
              log: latest,
              signal: guidance.signal,
              yesterdayRead: guidance.yesterdayRead,
              target: target,
            ),
          ],
        ],
      ),
    );
  }
}

String _todayDateKey() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

class _NoGuidancePlaceholder extends StatelessWidget {
  const _NoGuidancePlaceholder({required this.isStale});

  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final hint = isStale ? l.noGuidanceHintStale : l.noGuidanceHintMissing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.paper.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.noGuidanceTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.paper.withValues(alpha: 0.48),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.paper.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionHeader extends StatelessWidget {
  const _NutritionHeader({
    required this.week,
    required this.day,
    required this.onEditProfile,
  });

  final int? week;
  final int? day;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final right = (week != null && day != null) ? l.weekDay(week!, day!) : '';
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onEditProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.person,
                    size: 14,
                    color: AppColors.sage,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.labelProfil,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(
          l.nutritionHeaderTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.paper,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              right,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.paper.withValues(alpha: 0.48),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignalConfig {
  const _SignalConfig({
    required this.label,
    required this.sub,
    required this.color,
    required this.pulse,
  });

  final String label;
  final String sub;
  final Color color;
  final bool pulse;
}

_SignalConfig _signalConfig(FuelSignal s, AppLocalizations l) {
  switch (s) {
    case FuelSignal.green:
      return _SignalConfig(
        label: l.signalGreenLight,
        sub: l.signalGreenLightSub,
        color: AppColors.sage,
        pulse: true,
      );
    case FuelSignal.hold:
      return _SignalConfig(
        label: l.signalHold,
        sub: l.signalHoldSub,
        color: AppColors.gold,
        pulse: false,
      );
    case FuelSignal.fuel:
      return _SignalConfig(
        label: l.signalFuelFirst,
        sub: l.signalFuelFirstSub,
        color: AppColors.coral,
        pulse: false,
      );
    case FuelSignal.deload:
      return _SignalConfig(
        label: l.signalDeloadBias,
        sub: l.signalDeloadBiasSub,
        color: AppColors.paper,
        pulse: false,
      );
  }
}

class _SignalBadge extends StatefulWidget {
  const _SignalBadge({required this.signal});

  final FuelSignal signal;

  @override
  State<_SignalBadge> createState() => _SignalBadgeState();
}

class _SignalBadgeState extends State<_SignalBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _signalConfig(widget.signal, AppLocalizations.of(context)!);
    final color = cfg.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (cfg.pulse)
                  AnimatedBuilder(
                    animation: _ctl,
                    builder: (_, _) {
                      final t = _ctl.value;
                      final pulse = (t < 0.5) ? t * 2 : (1 - t) * 2;
                      final scale = 1 + 1.2 * pulse;
                      final op = (1 - pulse).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: op,
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.30),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  cfg.sub,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.paper.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.paper.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class _CardHeaderRow extends StatelessWidget {
  const _CardHeaderRow({
    required this.label,
    required this.trailing,
    this.trailingColor,
  });

  final String label;
  final String trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.paper.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.paper.withValues(alpha: 0.48),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
                color: trailingColor ?? AppColors.paper.withValues(alpha: 0.48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelAdviceCard extends StatelessWidget {
  const _FuelAdviceCard({
    required this.day,
    required this.text,
    required this.mealName,
    required this.mealRationale,
  });

  final String day;
  final String text;
  final String mealName;
  final String mealRationale;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeaderRow(
            label: l.sectionTodaysFuel,
            trailing: day.toUpperCase(),
            trailingColor: AppColors.sage,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: AppColors.paper,
                  ),
                ),
                const SizedBox(height: 11),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: AppColors.sage),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.08),
                            border: Border(
                              top: BorderSide(
                                color: AppColors.sage.withValues(alpha: 0.20),
                              ),
                              right: BorderSide(
                                color: AppColors.sage.withValues(alpha: 0.20),
                              ),
                              bottom: BorderSide(
                                color: AppColors.sage.withValues(alpha: 0.20),
                              ),
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.sectionMealSuggestion,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: AppColors.sage,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                mealName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  height: 1.1,
                                  color: AppColors.paper,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mealRationale,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.paper.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelDiaryCard extends StatefulWidget {
  const _FuelDiaryCard({
    required this.entries,
    required this.sentToday,
    required this.onAdd,
    required this.onRemove,
    required this.onSend,
  });

  final List<FuelDiaryEntry> entries;
  final bool sentToday;
  final Future<void> Function(String text) onAdd;
  final Future<void> Function(String id) onRemove;
  final Future<void> Function(int score) onSend;

  @override
  State<_FuelDiaryCard> createState() => _FuelDiaryCardState();
}

class _FuelDiaryCardState extends State<_FuelDiaryCard> {
  final _input = TextEditingController();
  double _score = 8;
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = widget.entries;
    return _WhiteCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l.fuelDiaryTitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.paper.withValues(alpha: 0.48),
                  ),
                ),
                const Spacer(),
                if (widget.sentToday)
                  Text(
                    l.fuelDiarySentLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                      color: AppColors.sage,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.fuelQualityLevel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.paper,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _score.round().toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.sage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.sage,
                inactiveTrackColor: AppColors.paper.withValues(alpha: 0.12),
                thumbColor: AppColors.sage,
                overlayColor: AppColors.sage.withValues(alpha: 0.14),
                tickMarkShape: SliderTickMarkShape.noTickMark,
                trackHeight: 4,
              ),
              child: Slider(
                value: _score,
                min: 1,
                max: 10,
                divisions: 9,
                label: '${_score.round()} / 10',
                onChanged: (value) => setState(() => _score = value),
              ),
            ),
            Row(
              children: [
                Text(
                  l.fuelScalePoor,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.paper.withValues(alpha: 0.42),
                  ),
                ),
                const Spacer(),
                Text(
                  l.fuelScalePerfect,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.paper.withValues(alpha: 0.42),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l.fuelDiaryEmptyHint,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paper.withValues(alpha: 0.36),
                  ),
                ),
              )
            else
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _timeLabel(entry.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: AppColors.sage.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.text,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.paper,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onRemove(entry.id),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.paper.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addEntry(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.paper,
                    ),
                    decoration: InputDecoration(
                      hintText: l.fuelDiaryHint,
                      hintStyle: TextStyle(
                        color: AppColors.paper.withValues(alpha: 0.28),
                      ),
                      filled: true,
                      fillColor: AppColors.paper.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppColors.paper.withValues(alpha: 0.08),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppColors.sage.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  width: 38,
                  child: IconButton(
                    onPressed: _addEntry,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.sage.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: AppColors.sage,
                    ),
                  ),
                ),
              ],
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  onPressed: _sending
                      ? null
                      : () async {
                          setState(() => _sending = true);
                          await widget.onSend(_score.round());
                          if (mounted) setState(() => _sending = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sage,
                    disabledBackgroundColor: AppColors.sage.withValues(
                      alpha: 0.35,
                    ),
                    foregroundColor: AppColors.paper,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _sending
                        ? l.fuelDiarySending
                        : widget.sentToday
                        ? l.fuelDiaryUpdateCoach
                        : l.fuelDiarySendToCoach,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addEntry() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    await widget.onAdd(text);
  }
}

enum _Level { low, moderate, high }

class _YesterdayCard extends StatelessWidget {
  const _YesterdayCard({
    required this.log,
    required this.signal,
    required this.yesterdayRead,
    required this.target,
  });

  final NutritionLog? log;
  final FuelSignal signal;
  final String yesterdayRead;
  final NutritionTarget target;

  @override
  Widget build(BuildContext context) {
    final p = log?.protein ?? 0;
    final c = log?.carbs ?? 0;
    final proteinLevel = log == null
        ? _Level.moderate
        : p >= target.protein * 0.95
        ? _Level.high
        : p >= target.protein * 0.60
        ? _Level.moderate
        : _Level.low;
    final carbsLevel = log == null
        ? _Level.moderate
        : c >= target.carbs * 0.85
        ? _Level.high
        : c >= target.carbs * 0.55
        ? _Level.moderate
        : _Level.low;
    const hydrationLevel = _Level.moderate;

    final l = AppLocalizations.of(context)!;
    return _WhiteCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.sectionYesterdaysSignal,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.paper.withValues(alpha: 0.48),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _SignalChip(
                    label: l.chipProtein,
                    level: proteinLevel,
                    value: log == null ? '—' : '${p}g',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SignalChip(
                    label: l.chipCarbs,
                    level: carbsLevel,
                    value: log == null ? '—' : '${c}g',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SignalChip(
                    label: l.chipHydration,
                    level: hydrationLevel,
                    value: '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              yesterdayRead,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.4,
                color: AppColors.paper.withValues(alpha: 0.50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.label,
    required this.level,
    required this.value,
  });

  final String label;
  final _Level level;
  final String value;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (color, levelLabel) = switch (level) {
      _Level.high => (AppColors.sage, l.levelHigh),
      _Level.moderate => (AppColors.gold, l.levelModerate),
      _Level.low => (AppColors.coral, l.levelLow),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: AppColors.paper.withValues(alpha: 0.48),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            levelLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.paper.withValues(alpha: 0.48),
            ),
          ),
        ],
      ),
    );
  }
}

Color _mealIdeaTagColor(String tag) {
  switch (tag) {
    case 'post-training':
      return AppColors.sage;
    case 'pre-training':
      return AppColors.gold;
    default:
      return AppColors.coral;
  }
}

// ignore: unused_element
class _MealIdeasRow extends StatelessWidget {
  const _MealIdeasRow({required this.ideas});

  final List<MealIdea> ideas;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ideas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _MealIdeaCard(idea: ideas[i]),
      ),
    );
  }
}

class _MealIdeaCard extends StatelessWidget {
  const _MealIdeaCard({required this.idea});

  final MealIdea idea;

  @override
  Widget build(BuildContext context) {
    final tagColor = _mealIdeaTagColor(idea.tag);
    return Container(
      width: 150,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppColors.paper.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            idea.tag.toUpperCase().replaceAll('-', ' '),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: tagColor,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            idea.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.15,
              color: AppColors.paper,
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              idea.why,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.paper.withValues(alpha: 0.48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealResultCardV2 extends StatefulWidget {
  const _MealResultCardV2({
    required this.result,
    required this.onAccept,
    required this.onDiscard,
    required this.onReview,
  });

  final MealAnalysisResult result;
  final VoidCallback onAccept;
  final VoidCallback onDiscard;
  final VoidCallback onReview;

  @override
  State<_MealResultCardV2> createState() => _MealResultCardV2State();
}

class _MealResultCardV2State extends State<_MealResultCardV2> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final r = widget.result;
    final time = _hhmm(r.analyzedAt);
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeaderRow(label: l.sectionMealAnalysis, trailing: time),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: widget.onReview,
                  child: Text(
                    r.mealDescription.isEmpty
                        ? l.mahlzeit
                        : r.mealDescription.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: AppColors.paper,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (r.rationale.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(left: 11),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.sage, width: 3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.sectionTrainingImpact,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: AppColors.sage,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.rationale,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.paper.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 11),
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 150),
                          turns: _expanded ? 0.25 : 0,
                          child: Icon(
                            CupertinoIcons.right_chevron,
                            size: 11,
                            color: AppColors.paper.withValues(alpha: 0.48),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _expanded
                              ? l.btnMakrosAusblenden
                              : '${r.calories} kcal · ${r.protein}g Protein · ${l.btnDetails}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.paper.withValues(alpha: 0.48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded) ...[
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _MacroChip(
                          label: 'KCAL',
                          value: '${r.calories}',
                          accent: false,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _MacroChip(
                          label: 'PROTEIN',
                          value: '${r.protein}g',
                          accent: true,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _MacroChip(
                          label: 'CARBS',
                          value: '${r.carbs}g',
                          accent: false,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _MacroChip(
                          label: 'FAT',
                          value: '${r.fat}g',
                          accent: false,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: FilledButton(
                          onPressed: widget.onAccept,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.sage,
                            foregroundColor: AppColors.paper,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: Text(
                            l.btnSpeichern,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          onPressed: widget.onDiscard,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.paper.withValues(
                              alpha: 0.07,
                            ),
                            foregroundColor: AppColors.paper.withValues(
                              alpha: AppOpacity.mutedText,
                            ),
                            side: BorderSide(
                              color: AppColors.paper.withValues(alpha: 0.10),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          child: Text(
                            l.btnVerwerfen,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? AppColors.sage.withValues(alpha: 0.10)
            : AppColors.paper.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: accent
            ? Border.all(color: AppColors.sage.withValues(alpha: 0.22))
            : null,
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: accent ? AppColors.sage : AppColors.paper,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: AppColors.paper.withValues(alpha: 0.48),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _MealAnalysisCta extends StatelessWidget {
  const _MealAnalysisCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _DashedRRectPainter(
          radius: 14,
          color: AppColors.paper.withValues(alpha: 0.15),
          strokeWidth: 1.5,
          dashLength: 4,
          gapLength: 3,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.paper.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(
                    color: AppColors.paper.withValues(alpha: 0.10),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.plus,
                  size: 18,
                  color: AppColors.paper.withValues(alpha: 0.48),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final l = AppLocalizations.of(context)!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.mahlzeitAnalysieren,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.paper,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.coachBewertetTrainingsauswirkung,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.paper.withValues(alpha: 0.48),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Coach Hub ──────────────────────────────────────────────────────────────

class _CoachPage extends StatefulWidget {
  const _CoachPage({required this.controller});

  final dynamic controller;

  @override
  State<_CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<_CoachPage> {
  int _tab = 0; // 0 = Plan, 1 = Memory, 2 = Sync

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data as FitnessData;
    final block = widget.controller.activeBlock as TrainingBlock?;

    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        children: [
          if (block != null)
            _BlockBanner(
              block: block,
              completedSessions: _completedCount(data, block),
            ),
          _CoachSegmentControl(
            active: _tab,
            onChange: (i) => setState(() => _tab = i),
            hasSyncBadge: widget.controller.hasPendingCoachBlock as bool,
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _CoachPlanTab(
                  controller: widget.controller,
                  data: data,
                  block: block,
                ),
                _CoachMemoryTab(
                  controller: widget.controller,
                  memories: data.memories,
                ),
                _CoachSyncTab(controller: widget.controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _completedCount(FitnessData data, TrainingBlock block) {
    final blockWorkoutIds = block.workouts.map((w) => w.id).toSet();
    return data.logs
        .where(
          (log) =>
              log.completedAt != null &&
              blockWorkoutIds.contains(log.workoutId),
        )
        .length;
  }
}

// ─── Block Banner ───────────────────────────────────────────────────────────

class _BlockBanner extends StatelessWidget {
  const _BlockBanner({required this.block, required this.completedSessions});

  final TrainingBlock block;
  final int completedSessions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final total = block.workouts.length;
    final dotCount = total.clamp(0, 20);
    final pct = total > 0 ? completedSessions / total : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.18)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -28,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sage.withValues(alpha: 0.09),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.aktiverBlock,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.sage.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          block.title,
                          style: const TextStyle(
                            fontFamily: 'RussoOne',
                            fontSize: 17,
                            color: AppColors.paper,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          block.style.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.paper.withValues(alpha: 0.36),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$completedSessions',
                        style: const TextStyle(
                          fontFamily: 'RussoOne',
                          fontSize: 28,
                          color: AppColors.sage,
                          height: 1,
                        ),
                      ),
                      Text(
                        l.sessionsLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: AppColors.sage.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (var i = 0; i < dotCount; i++)
                    _SessionDot(
                      isDone: i < completedSessions,
                      isNext: i == completedSessions,
                    ),
                  if (total > 20)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        '+${total - 20}',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.paper.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct.clamp(0, 1).toDouble(),
                  minHeight: 3,
                  backgroundColor: AppColors.paper.withValues(alpha: 0.14),
                  valueColor: const AlwaysStoppedAnimation(AppColors.sage),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionDot extends StatelessWidget {
  const _SessionDot({required this.isDone, required this.isNext});

  final bool isDone;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final size = isNext ? 10.0 : 8.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone
            ? AppColors.sage
            : isNext
            ? AppColors.transparent
            : AppColors.paper.withValues(alpha: 0.14),
        border: isNext ? Border.all(color: AppColors.sage, width: 1.5) : null,
      ),
    );
  }
}

// ─── Segment Control ────────────────────────────────────────────────────────

class _CoachSegmentControl extends StatelessWidget {
  const _CoachSegmentControl({
    required this.active,
    required this.onChange,
    required this.hasSyncBadge,
  });

  final int active;
  final ValueChanged<int> onChange;
  final bool hasSyncBadge;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tabs = [l.coachSegmentPlan, l.coachSegmentMemory, l.coachSegmentSync];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChange(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: active == i
                        ? AppColors.surface3
                        : AppColors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: active == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.30),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (i == 2 && hasSyncBadge) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active == i
                                ? AppColors.sage
                                : AppColors.paper.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: active == i
                              ? AppColors.paper
                              : AppColors.paper.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── PLAN TAB ───────────────────────────────────────────────────────────────

class _CoachPlanTab extends StatelessWidget {
  const _CoachPlanTab({
    required this.controller,
    required this.data,
    required this.block,
  });

  final dynamic controller;
  final FitnessData data;
  final TrainingBlock? block;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final nextWorkout = data.nextWorkout;
    final completedLogs =
        data.logs.where((log) => log.completedAt != null).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (data.coachingGoals != null)
          _GoalsCard(goals: data.coachingGoals!),
        if (data.yesterdaySummary != null) ...[
          const SizedBox(height: 8),
          _YesterdaySummaryCard(summary: data.yesterdaySummary!),
        ],
        if (data.coachingGoals != null || data.yesterdaySummary != null)
          const SizedBox(height: 8),
        _NextSessionCard(
          controller: controller,
          workout: nextWorkout,
          block: block,
          sessionNumber: completedLogs.length + 1,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.verlauf,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.paper.withValues(alpha: 0.45),
              ),
            ),
            Text(
              l.sessionsCount(completedLogs.length),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.paper.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (completedLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.paper.withValues(alpha: 0.07),
              ),
            ),
            child: Text(
              l.nochKeineSessions,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.paper.withValues(alpha: 0.45),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.paper.withValues(alpha: 0.07),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (var i = 0; i < completedLogs.length; i++)
                  _LogRow(
                    log: completedLogs[i],
                    index: completedLogs.length - i,
                    isLast: i == completedLogs.length - 1,
                  ),
              ],
            ),
          ),
        if (completedLogs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l.alleSessions(completedLogs.length),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.paper.withValues(alpha: 0.26),
              ),
            ),
          ),
      ],
    );
  }
}

class _NextSessionCard extends StatefulWidget {
  const _NextSessionCard({
    required this.controller,
    required this.workout,
    required this.block,
    required this.sessionNumber,
  });

  final dynamic controller;
  final PlannedWorkout? workout;
  final TrainingBlock? block;
  final int sessionNumber;

  @override
  State<_NextSessionCard> createState() => _NextSessionCardState();
}

class _NextSessionCardState extends State<_NextSessionCard> {
  bool _rationaleOpen = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final workout = widget.workout;
    if (workout == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.paper.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.paper.withValues(alpha: 0.07),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.naechsteSession,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.paper.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.wirdHeuteAbendGeneriert,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.paper.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.verfuegbarNach2100,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.paper.withValues(alpha: 0.26),
              ),
            ),
          ],
        ),
      );
    }

    final focus = [
      workout.focus,
      l.exerciseCount(workout.exercises.length),
    ].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.sage.withValues(alpha: 0.22),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppColors.sage.withValues(alpha: 0.09),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.naechsteSession,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.sage,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: AppColors.sage.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    l.sessionNumber(widget.sessionNumber),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      color: AppColors.sage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.title,
                  style: const TextStyle(
                    fontFamily: 'RussoOne',
                    fontSize: 20,
                    color: AppColors.paper,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  focus,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.paper.withValues(alpha: 0.45),
                  ),
                ),
                if (workout.rationale.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _rationaleOpen = !_rationaleOpen),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.sage.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.sage.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l.coachNotizLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                    color: AppColors.sage,
                                  ),
                                ),
                              ),
                              AnimatedRotation(
                                turns: _rationaleOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 180),
                                child: Text(
                                  '▾',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.sage.withValues(
                                      alpha: 0.60,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workout.rationale.trim(),
                            maxLines: _rationaleOpen ? 100 : 1,
                            overflow: _rationaleOpen
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.sage,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => widget.controller.startCurrentWorkout(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sage,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l.workoutStarten,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.paper,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: AppColors.paper.withValues(alpha: 0.70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatefulWidget {
  const _LogRow({required this.log, required this.index, required this.isLast});

  final WorkoutLog log;
  final int index;
  final bool isLast;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final log = widget.log;
    final avgRpe = log.sets.isEmpty
        ? 0.0
        : log.sets.fold<double>(0, (s, set) => s + set.rpe) / log.sets.length;
    final rpeColor = avgRpe >= 8
        ? AppColors.coral
        : avgRpe >= 7
        ? AppColors.gold
        : AppColors.sage;
    final volume = log.totalVolume;
    final dateStr = _formatLogDate(log.startedAt, locale);

    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: widget.isLast && !_open
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.paper.withValues(alpha: 0.04),
                  ),
                ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: AppColors.paper.withValues(alpha: 0.06),
                    border: Border.all(
                      color: AppColors.paper.withValues(alpha: 0.07),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.index}',
                    style: TextStyle(
                      fontFamily: 'RussoOne',
                      fontSize: 13,
                      color: AppColors.paper.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.paper,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr · ${l.logSaetze(log.sets.length)} · ${(volume / 1000).toStringAsFixed(1)}t',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.paper.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                if (log.sets.isNotEmpty)
                  Column(
                    children: [
                      Text(
                        avgRpe.toStringAsFixed(1),
                        style: TextStyle(
                          fontFamily: 'RussoOne',
                          fontSize: 15,
                          color: rpeColor,
                          height: 1,
                        ),
                      ),
                      Text(
                        'RPE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.paper.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '▾',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.paper.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_open) _LogDetail(log: log),
          ],
        ),
      ),
    );
  }
}

class _LogDetail extends StatelessWidget {
  const _LogDetail({required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final grouped = <String, List<LoggedSet>>{};
    for (final s in log.sets) {
      grouped
          .putIfAbsent(
            s.exerciseName.isEmpty ? s.exerciseId : s.exerciseName,
            () => [],
          )
          .add(s);
    }

    final duration = log.totalDurationSeconds;
    final durationStr = duration != null ? '${duration ~/ 60} min' : null;

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 44, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration + readiness + soreness summary
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (durationStr != null)
                _LogMetaChip(label: l.dauerLabel, value: durationStr),
              if (log.readiness > 0)
                _LogMetaChip(label: 'Readiness', value: '${log.readiness}/5'),
              if (log.soreness > 0)
                _LogMetaChip(label: 'Soreness', value: '${log.soreness}/5'),
            ],
          ),
          if (grouped.isNotEmpty) const SizedBox(height: 10),
          for (final entry in grouped.entries)
            _LogExerciseGroup(name: entry.key, sets: entry.value),
          if (log.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.sage.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                log.notes.trim(),
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.sage,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LogMetaChip extends StatelessWidget {
  const _LogMetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.paper.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.paper,
          ),
        ),
      ],
    );
  }
}

class _LogExerciseGroup extends StatelessWidget {
  const _LogExerciseGroup({required this.name, required this.sets});

  final String name;
  final List<LoggedSet> sets;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.paper,
            ),
          ),
          const SizedBox(height: 4),
          for (final s in sets)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      'S${s.setNumber}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.paper.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      [
                        l.wdhlCount(s.reps),
                        if (s.weightKg > 0)
                          '${s.weightKg.toStringAsFixed(s.weightKg == s.weightKg.roundToDouble() ? 0 : 1)} kg',
                        'RPE ${s.rpe == s.rpe.roundToDouble() ? s.rpe.toInt().toString() : s.rpe.toStringAsFixed(1)}',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.paper.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _formatLogDate(DateTime date, String locale) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final logDay = DateTime(date.year, date.month, date.day);
  final diff = today.difference(logDay).inDays;
  final isGerman = locale.startsWith('de');
  if (diff == 0) {
    final time = DateFormat.Hm(locale).format(date);
    return isGerman ? 'Heute, $time' : 'Today, $time';
  }
  if (diff == 1) return isGerman ? 'Gestern' : 'Yesterday';
  return DateFormat('E, d. MMM', locale).format(date);
}

// ─── GOALS CARD ─────────────────────────────────────────────────────────────

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.goals});
  final CoachingGoals goals;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final paper = AppColors.paper;

    String? countdownText;
    final reviewDate = goals.blockReviewDate;
    if (reviewDate != null) {
      final target = DateTime.tryParse(reviewDate);
      if (target != null) {
        final days = target.difference(DateTime.now()).inDays;
        if (days > 0) {
          countdownText = l.daysLeft(days);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: paper.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.goalsLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: paper.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              if (countdownText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    countdownText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sage.withValues(alpha: 0.85),
                    ),
                  ),
                ),
            ],
          ),
          if (goals.longTerm.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              goals.longTerm,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: paper,
                height: 1.3,
              ),
            ),
          ],
          if (goals.shortTerm.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              goals.shortTerm,
              style: TextStyle(
                fontSize: 12,
                color: paper.withValues(alpha: 0.55),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── YESTERDAY SUMMARY CARD ─────────────────────────────────────────────────

class _YesterdaySummaryCard extends StatefulWidget {
  const _YesterdaySummaryCard({required this.summary});
  final YesterdaySummary summary;

  @override
  State<_YesterdaySummaryCard> createState() => _YesterdaySummaryCardState();
}

class _YesterdaySummaryCardState extends State<_YesterdaySummaryCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final paper = AppColors.paper;
    final summary = widget.summary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: paper.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  l.yesterdayLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: paper.withValues(alpha: 0.45),
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: paper.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
          if (summary.headline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary.headline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: paper,
                height: 1.3,
              ),
            ),
          ],
          if (_expanded) ...[
            if (summary.highlights.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final h in summary.highlights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5, right: 8),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.sage.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: 12,
                            color: paper.withValues(alpha: 0.55),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (summary.tips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                l.tipsLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.gold.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              for (final t in summary.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 6),
                        child: Icon(
                          Icons.info_outline,
                          size: 13,
                          color: AppColors.gold.withValues(alpha: 0.55),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12,
                            color: paper.withValues(alpha: 0.55),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─── MEMORY TAB ─────────────────────────────────────────────────────────────

class _CoachMemoryTab extends StatefulWidget {
  const _CoachMemoryTab({required this.controller, required this.memories});

  final dynamic controller;
  final List<MemoryEntry> memories;

  @override
  State<_CoachMemoryTab> createState() => _CoachMemoryTabState();
}

class _CoachMemoryTabState extends State<_CoachMemoryTab> {
  String _filter = 'all'; // 'all' | 'memory' | 'constraint'

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final memories = widget.memories;
    final activeCount = memories.where((m) => m.active).length;

    final visible = _filter == 'all'
        ? memories
        : _filter == 'memory'
        ? memories
              .where((m) => m.category != MemoryCategory.constraint)
              .toList()
        : memories
              .where((m) => m.category == MemoryCategory.constraint)
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                children: [
                  _MemFilterChip(
                    label: l.memFilterAlle,
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  _MemFilterChip(
                    label: l.memFilterMemories,
                    active: _filter == 'memory',
                    onTap: () => setState(() => _filter = 'memory'),
                    activeColor: AppColors.sage,
                  ),
                  _MemFilterChip(
                    label: l.memFilterConstraints,
                    active: _filter == 'constraint',
                    onTap: () => setState(() => _filter = 'constraint'),
                    activeColor: AppColors.coral,
                  ),
                ],
              ),
            ),
            Text(
              l.memoryWikiAktiv(activeCount),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.paper.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.paper.withValues(alpha: 0.07)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    l.keineEintraege,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.paper.withValues(alpha: 0.45),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < visible.length; i++)
                      _MemRow(
                        mem: visible[i],
                        isLast: i == visible.length - 1,
                        onToggle: (val) =>
                            widget.controller.toggleMemory(visible[i].id, val),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l.agentLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                    TextSpan(
                      text: ' = ${l.coachEquals}  ·  ',
                      style: TextStyle(
                        color: AppColors.paper.withValues(alpha: 0.45),
                      ),
                    ),
                    TextSpan(
                      text: l.ichLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.paper.withValues(alpha: 0.45),
                      ),
                    ),
                    TextSpan(
                      text: ' = ${l.vonDirLabel}',
                      style: TextStyle(
                        color: AppColors.paper.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 10),
              ),
            ),
            GestureDetector(
              onTap: () => _showMemoryDialog(context, widget.controller),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  l.memHinzufuegen,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sage,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MemFilterChip extends StatelessWidget {
  const _MemFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.activeColor,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final color = activeColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (color != null
                    ? color.withValues(alpha: 0.12)
                    : AppColors.paper.withValues(alpha: 0.08))
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: active
                ? (color != null
                      ? color.withValues(alpha: 0.26)
                      : AppColors.paper.withValues(alpha: 0.18))
                : AppColors.paper.withValues(alpha: 0.07),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: active
                ? (color ?? AppColors.paper)
                : AppColors.paper.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _MemRow extends StatefulWidget {
  const _MemRow({
    required this.mem,
    required this.isLast,
    required this.onToggle,
  });

  final MemoryEntry mem;
  final bool isLast;
  final ValueChanged<bool> onToggle;

  @override
  State<_MemRow> createState() => _MemRowState();
}

class _MemRowState extends State<_MemRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mem = widget.mem;
    final isConstraint = mem.category == MemoryCategory.constraint;
    final typeLabel = isConstraint ? l.constraintLabel : l.memoryLabel;
    final typeColor = isConstraint ? AppColors.coral : AppColors.sage;
    final isAgent = mem.source != 'manual' && mem.source != 'user';
    final sourceLabel = isAgent ? l.agentLabel : l.ichLabel;
    final sourceColor = isAgent
        ? AppColors.gold
        : AppColors.paper.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: mem.active ? 1 : 0.45,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: widget.isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: AppColors.paper.withValues(alpha: 0.04),
                    ),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 72),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: typeColor.withValues(alpha: 0.26),
                    ),
                  ),
                  child: Text(
                    typeLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: typeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mem.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.paper,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mem.summary,
                      maxLines: _open ? 100 : 1,
                      overflow: _open
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.paper.withValues(alpha: 0.45),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  sourceLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: sourceColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── SYNC TAB ───────────────────────────────────────────────────────────────

class _CoachSyncTab extends StatelessWidget {
  const _CoachSyncTab({required this.controller});

  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final bridge = controller.bridgeConfig as LocalBridgeConfig;
    final isConfigured = bridge.isConfigured;
    final hasPending = controller.hasPendingCoachBlock as bool;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        // Status strip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.paper.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              _SyncStatusDot(isConfigured: isConfigured),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConfigured
                          ? l.serverVerbunden
                          : l.keinServerKonfiguriert,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isConfigured
                            ? AppColors.paper
                            : AppColors.paper.withValues(alpha: 0.45),
                      ),
                    ),
                    if (isConfigured)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          bridge.baseUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.paper.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FitnessScope(
                      controller: controller,
                      child: const _SettingsScreen(),
                    ),
                  ),
                ),
                child: Text(
                  l.syncEinstellungen,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.paper.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l.syncAktionen,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: AppColors.paper.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 10),
        _SyncActionButton(
          icon: Icons.arrow_upward,
          label: l.contextPushen,
          sub: l.contextPushenSub,
          onTap: controller.exportDailySnapshot,
        ),
        const SizedBox(height: 10),
        _SyncActionButton(
          icon: Icons.arrow_downward,
          label: l.ergebnisseAbrufen,
          sub: l.ergebnisseAbrufenSub,
          onTap: controller.checkForCoachUpdates,
          accentColor: AppColors.sage,
          showBadge: hasPending,
        ),
        const SizedBox(height: 14),
        Text(
          l.serverConfigHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.paper.withValues(alpha: 0.26),
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _SyncStatusDot extends StatelessWidget {
  const _SyncStatusDot({required this.isConfigured});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isConfigured)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sage.withValues(alpha: 0.25),
              ),
            ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConfigured
                  ? AppColors.sage
                  : AppColors.paper.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncActionButton extends StatefulWidget {
  const _SyncActionButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.accentColor,
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool showBadge;

  @override
  State<_SyncActionButton> createState() => _SyncActionButtonState();
}

class _SyncActionButtonState extends State<_SyncActionButton> {
  bool _busy = false;
  bool _done = false;

  void _handle() {
    if (_busy) return;
    setState(() => _busy = true);
    widget.onTap();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _busy = false;
          _done = true;
        });
        Future.delayed(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _done = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = _done
        ? AppColors.sage.withValues(alpha: 0.10)
        : AppColors.paper.withValues(alpha: 0.05);
    final bdr = _done
        ? AppColors.sage.withValues(alpha: 0.24)
        : AppColors.paper.withValues(alpha: 0.07);
    final fg = _done ? AppColors.sage : (widget.accentColor ?? AppColors.paper);

    return GestureDetector(
      onTap: _handle,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bdr),
        ),
        child: Stack(
          children: [
            if (widget.showBadge && !_done)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.sage,
                  ),
                ),
              ),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _done
                        ? AppColors.sage.withValues(alpha: 0.12)
                        : (widget.accentColor ?? AppColors.paper).withValues(
                            alpha: 0.08,
                          ),
                    border: Border.all(
                      color: _done
                          ? AppColors.sage.withValues(alpha: 0.22)
                          : AppColors.paper.withValues(alpha: 0.07),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _busy
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.paper.withValues(alpha: 0.45),
                          ),
                        )
                      : _done
                      ? const Icon(Icons.check, size: 17, color: AppColors.sage)
                      : Icon(widget.icon, size: 17, color: fg),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _done
                            ? AppLocalizations.of(context)!.syncErledigt
                            : widget.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.sub,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.paper.withValues(alpha: 0.45),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_done && !_busy)
                  Text(
                    '›',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.paper.withValues(alpha: 0.26),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPill extends StatelessWidget {
  const _VideoPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.33)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.play_fill,
              size: 11,
              color: AppColors.sage,
            ),
            const SizedBox(width: 7),
            Text(
              AppLocalizations.of(context)!.erklaervideo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.sage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Uri? _exerciseVideoUri(ExercisePrescription exercise) {
  final raw = exercise.media?.explainerUrl.trim() ?? '';
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return _preferYoutubeShorts(uri);
}

Future<void> _openExerciseVideo(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Uri _preferYoutubeShorts(Uri uri) {
  final host = uri.host.toLowerCase();
  final isYoutube =
      host == 'youtu.be' ||
      host == 'youtube.com' ||
      host == 'www.youtube.com' ||
      host == 'm.youtube.com';
  if (!isYoutube) return uri;
  final segments = uri.pathSegments;
  if (segments.isNotEmpty && segments.first == 'shorts') return uri;
  String? id;
  if (host == 'youtu.be' && segments.isNotEmpty) {
    id = segments.first;
  } else if (segments.contains('watch')) {
    id = uri.queryParameters['v'];
  } else if (segments.length >= 2 &&
      (segments.first == 'embed' || segments.first == 'v')) {
    id = segments[1];
  }
  if (id == null || id.isEmpty) return uri;
  return Uri.parse('https://www.youtube.com/shorts/$id');
}

// ignore: unused_element
class _PendingMealRequestCard extends StatelessWidget {
  const _PendingMealRequestCard({required this.request});

  final MealAnalysisRequest request;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(CupertinoIcons.clock),
        title: Text(AppLocalizations.of(context)!.pendingMealTitle),
        subtitle: Text(
          request.description.isEmpty
              ? request.imagePath ?? AppLocalizations.of(context)!.btnFoto
              : request.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─── Progress Screen ────────────────────────────────────────────────────────

class _ProgressPage extends StatefulWidget {
  const _ProgressPage({required this.controller});

  final dynamic controller;

  @override
  State<_ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<_ProgressPage> {
  bool _daily = false;
  String _range = '4W';

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data as FitnessData;
    final completedLogs =
        data.logs.where((log) => log.completedAt != null).toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    if (completedLogs.isEmpty) {
      return ColoredBox(color: AppColors.bg, child: _ProgressEmptyState());
    }

    return ColoredBox(
      color: AppColors.bg,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Row(
              children: [
                _ViewModeToggle(
                  daily: _daily,
                  onChange: (v) => setState(() {
                    _daily = v;
                    _range = v ? '7D' : '4W';
                  }),
                ),
                const Spacer(),
                _ProgressRangeToggle(
                  value: _range,
                  daily: _daily,
                  onChange: (v) => setState(() => _range = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              children: [
                _VolumeChart(
                  logs: completedLogs,
                  range: _range,
                  daily: _daily,
                ),
                const SizedBox(height: 14),
                _HealthProgressCharts(
                  logs: completedLogs,
                  range: _range,
                  daily: _daily,
                ),
                const SizedBox(height: 14),
                _StrengthPRs(
                  controller: widget.controller,
                  logs: completedLogs,
                ),
                const SizedBox(height: 14),
                _ReadinessChart(logs: completedLogs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _ProgressEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 20),
      children: [
        // Motivator
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sage.withValues(alpha: 0.12),
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: 0.24),
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.chart_bar_alt_fill,
                  size: 26,
                  color: AppColors.sage,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.fortschrittStartetHier,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'RussoOne',
                  fontSize: 18,
                  color: AppColors.paper,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.fortschrittStartetHierSub,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.paper.withValues(alpha: 0.45),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Preview: what the charts will look like
        Text(
          l.wasErwartetDich,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: AppColors.paper.withValues(alpha: 0.28),
          ),
        ),
        const SizedBox(height: 8),

        // Volume preview
        _EmptyPreviewRow(
          icon: CupertinoIcons.chart_bar,
          title: l.volumenProWoche,
          sub: l.volumePreviewSub,
        ),
        const SizedBox(height: 8),

        // PRs preview
        _EmptyPreviewRow(
          icon: CupertinoIcons.arrow_up_right,
          title: l.staerkePRsTitle,
          sub: l.staerkePRsSub,
        ),
        const SizedBox(height: 8),

        // Readiness preview
        _EmptyPreviewRow(
          icon: CupertinoIcons.heart,
          title: l.bereitschaftErschoepfung,
          sub: l.bereitschaftErschoepfungSub,
        ),

        const SizedBox(height: 24),

        // Ghost chart preview
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.volumenProWoche,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: AppColors.paper.withValues(alpha: 0.18),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final h in [0.3, 0.45, 0.55, 0.5, 0.65, 0.72, 0.85])
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 80 * h,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            color: AppColors.sage.withValues(alpha: 0.08),
                            border: Border.all(
                              color: AppColors.sage.withValues(alpha: 0.10),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  l.volumeChartPlaceholder,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.sage.withValues(alpha: 0.40),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyPreviewRow extends StatelessWidget {
  const _EmptyPreviewRow({
    required this.icon,
    required this.title,
    required this.sub,
  });

  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: AppColors.sage.withValues(alpha: 0.10),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, size: 16, color: AppColors.sage),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.paper,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.paper.withValues(alpha: 0.40),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── View Mode Toggle ────────────────────────────────────────────────────────

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.daily, required this.onChange});

  final bool daily;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in [
            (false, l.viewWeekly),
            (true, l.viewDaily),
          ])
            GestureDetector(
              onTap: () => onChange(entry.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: daily == entry.$1
                      ? AppColors.surface3
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: daily == entry.$1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  entry.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: daily == entry.$1
                        ? AppColors.paper
                        : AppColors.paper.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Range Toggle ─────────────────────────────────────────────────────────────

class _ProgressRangeToggle extends StatelessWidget {
  const _ProgressRangeToggle({
    required this.value,
    required this.daily,
    required this.onChange,
  });

  final String value;
  final bool daily;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final options = daily
        ? ['7D', '14D', '30D']
        : ['4W', '8W', l.gesamt];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final v in options)
            GestureDetector(
              onTap: () => onChange(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: value == v
                      ? AppColors.surface3
                      : AppColors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: value == v
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  v,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: value == v
                        ? AppColors.paper
                        : AppColors.paper.withValues(alpha: 0.38),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Volume Bar Chart ─────────────────────────────────────────────────────────

class _VolumeChart extends StatelessWidget {
  const _VolumeChart({
    required this.logs,
    required this.range,
    required this.daily,
  });

  final List<WorkoutLog> logs;
  final String range;
  final bool daily;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final volumes = daily
        ? _computeDailyVolumes(locale)
        : _computeWeeklyVolumes();
    if (volumes.isEmpty) {
      return _ProgressCard(
        label: daily ? l.volumenProTag : l.volumenProWoche,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            l.nochKeineDaten,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.paper.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }

    final maxVal = volumes
        .map((e) => e.$2)
        .reduce((a, b) => a > b ? a : b);
    final latest = volumes.last.$2;
    final avg =
        volumes.map((e) => e.$2).reduce((a, b) => a + b) /
        volumes.length;
    final first = volumes.first.$2;
    final growthPct = first > 0
        ? ((latest - first) / first * 100).round()
        : 0;

    return _ProgressCard(
      label: daily ? l.volumenProTag : l.volumenProWoche,
      child: Column(
        children: [
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < volumes.length; i++) ...[
                  if (i > 0) SizedBox(width: volumes.length > 14 ? 2 : volumes.length > 8 ? 4 : 7),
                  Expanded(
                    child: _VolumeBar(
                      label: volumes[i].$1,
                      value: volumes[i].$2,
                      maxVal: maxVal,
                      isLast: i == volumes.length - 1,
                      chartHeight: 88,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.paper.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                _VolumeStat(
                  label: daily ? l.heute : l.dieseWoche,
                  value: _fmtVol(latest),
                ),
                _VolumeDivider(),
                _VolumeStat(
                  label: daily ? l.avgProTag : l.avgProWoche,
                  value: _fmtVol(avg.round().toDouble()),
                ),
                if (growthPct != 0) ...[
                  _VolumeDivider(),
                  _VolumeStat(
                    label: l.zuwachs,
                    value: '${growthPct > 0 ? '+' : ''}$growthPct%',
                    color: AppColors.sage,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<(String, double)> _computeWeeklyVolumes() {
    if (logs.isEmpty) return [];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    final weeksBack = range == '4W'
        ? 4
        : range == '8W'
        ? 8
        : 52;
    final result = <(String, double)>[];

    for (var w = weeksBack - 1; w >= 0; w--) {
      final start = currentWeekStart.subtract(Duration(days: w * 7));
      final end = start.add(const Duration(days: 7));
      final vol = logs
          .where(
            (log) =>
                log.startedAt.isAfter(start) && log.startedAt.isBefore(end),
          )
          .fold<double>(0, (sum, log) => sum + log.totalVolume);
      if (vol > 0 || result.isNotEmpty) {
        result.add(('W${result.length + 1}', vol));
      }
    }

    if (result.isEmpty) {
      result.add((
        'W1',
        logs.fold<double>(0, (sum, log) => sum + log.totalVolume),
      ));
    }

    return result;
  }

  List<(String, double)> _computeDailyVolumes(String locale) {
    if (logs.isEmpty) return [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysBack = range == '7D' ? 7 : range == '14D' ? 14 : 30;
    final result = <(String, double)>[];

    for (var d = daysBack - 1; d >= 0; d--) {
      final start = today.subtract(Duration(days: d));
      final end = start.add(const Duration(days: 1));
      final vol = logs
          .where(
            (log) =>
                !log.startedAt.isBefore(start) && log.startedAt.isBefore(end),
          )
          .fold<double>(0, (sum, log) => sum + log.totalVolume);
      if (vol > 0 || result.isNotEmpty) {
        final label = DateFormat('E', locale).format(start).substring(0, 2);
        result.add((label, vol));
      }
    }

    if (result.isEmpty) {
      result.add((
        DateFormat('E', locale).format(today).substring(0, 2),
        logs.fold<double>(0, (sum, log) => sum + log.totalVolume),
      ));
    }

    return result;
  }

  static String _fmtVol(double v) {
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(1).replaceAll('.', ',')} t';
    }
    return '${v.toStringAsFixed(0)} kg';
  }
}

class _VolumeBar extends StatelessWidget {
  const _VolumeBar({
    required this.label,
    required this.value,
    required this.maxVal,
    required this.isLast,
    required this.chartHeight,
  });

  final String label;
  final double value;
  final double maxVal;
  final bool isLast;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    final h = maxVal > 0
        ? (value / maxVal * chartHeight).clamp(2.0, chartHeight)
        : 2.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: double.infinity,
          height: h,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
              bottom: Radius.circular(2),
            ),
            gradient: isLast
                ? null
                : LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.sage.withValues(alpha: 0.55),
                      AppColors.sage.withValues(alpha: 0.75),
                    ],
                  ),
            color: isLast ? AppColors.sage : null,
            boxShadow: isLast
                ? [
                    BoxShadow(
                      color: AppColors.sage.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            color: isLast
                ? AppColors.sage
                : AppColors.paper.withValues(alpha: 0.28),
          ),
        ),
      ],
    );
  }
}

class _VolumeStat extends StatelessWidget {
  const _VolumeStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'RussoOne',
              fontSize: 16,
              color: color ?? AppColors.paper,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.paper.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppColors.paper.withValues(alpha: 0.06),
    );
  }
}

// ── Health Metrics Charts ───────────────────────────────────────────────────

class _HealthProgressCharts extends StatelessWidget {
  const _HealthProgressCharts({
    required this.logs,
    required this.range,
    required this.daily,
  });

  final List<WorkoutLog> logs;
  final String range;
  final bool daily;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final points = daily
        ? _computeDailyHealth(locale)
        : _computeWeeklyHealth();
    final hasCalories = points.any((p) => p.activeEnergyKcal > 0);
    final hasHeartRate = points.any((p) => p.averageHeartRateBpm != null);
    if (!hasCalories && !hasHeartRate) return const SizedBox.shrink();

    return Column(
      children: [
        if (hasCalories)
          _ProgressCard(
            label: 'CALORIES BURNED',
            child: _WeeklyCaloriesChart(weeks: points, daily: daily),
          ),
        if (hasCalories && hasHeartRate) const SizedBox(height: 14),
        if (hasHeartRate)
          _ProgressCard(
            label: 'TRAINING HEART RATE',
            child: _WeeklyHeartRateChart(weeks: points, daily: daily),
          ),
      ],
    );
  }

  List<_WeeklyHealthPoint> _computeWeeklyHealth() {
    if (logs.isEmpty) return const [];
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final currentWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weeksBack = range == '4W'
        ? 4
        : range == '8W'
        ? 8
        : 52;
    final result = <_WeeklyHealthPoint>[];

    for (var w = weeksBack - 1; w >= 0; w--) {
      final start = currentWeekStart.subtract(Duration(days: w * 7));
      final end = start.add(const Duration(days: 7));
      final weekLogs = logs
          .where(
            (log) =>
                !log.startedAt.isBefore(start) && log.startedAt.isBefore(end),
          )
          .toList();
      final metrics = weekLogs.map(_metricsForHealthChart).toList();
      final calories = metrics.fold<double>(
        0,
        (sum, metric) => sum + (metric.activeEnergyKcal ?? 0),
      );
      final heartRates = metrics
          .map((metric) => metric.heartRateBpm)
          .whereType<double>()
          .toList();
      final avgHr = heartRates.isEmpty
          ? null
          : heartRates.fold<double>(0, (sum, hr) => sum + hr) /
                heartRates.length;
      if (calories > 0 || avgHr != null || result.isNotEmpty) {
        result.add(
          _WeeklyHealthPoint(
            label: 'W${result.length + 1}',
            activeEnergyKcal: calories,
            averageHeartRateBpm: avgHr,
          ),
        );
      }
    }

    if (result.isEmpty) {
      final metrics = logs.map(_metricsForHealthChart).toList();
      final calories = metrics.fold<double>(
        0,
        (sum, metric) => sum + (metric.activeEnergyKcal ?? 0),
      );
      final heartRates = metrics
          .map((metric) => metric.heartRateBpm)
          .whereType<double>()
          .toList();
      result.add(
        _WeeklyHealthPoint(
          label: 'W1',
          activeEnergyKcal: calories,
          averageHeartRateBpm: heartRates.isEmpty
              ? null
              : heartRates.fold<double>(0, (sum, hr) => sum + hr) /
                    heartRates.length,
        ),
      );
    }

    return result;
  }

  List<_WeeklyHealthPoint> _computeDailyHealth(String locale) {
    if (logs.isEmpty) return const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysBack = range == '7D' ? 7 : range == '14D' ? 14 : 30;
    final result = <_WeeklyHealthPoint>[];

    for (var d = daysBack - 1; d >= 0; d--) {
      final start = today.subtract(Duration(days: d));
      final end = start.add(const Duration(days: 1));
      final dayLogs = logs
          .where(
            (log) =>
                !log.startedAt.isBefore(start) && log.startedAt.isBefore(end),
          )
          .toList();
      final metrics = dayLogs.map(_metricsForHealthChart).toList();
      final calories = metrics.fold<double>(
        0,
        (sum, metric) => sum + (metric.activeEnergyKcal ?? 0),
      );
      final heartRates = metrics
          .map((metric) => metric.heartRateBpm)
          .whereType<double>()
          .toList();
      final avgHr = heartRates.isEmpty
          ? null
          : heartRates.fold<double>(0, (sum, hr) => sum + hr) /
                heartRates.length;
      if (calories > 0 || avgHr != null || result.isNotEmpty) {
        final label = DateFormat('E', locale).format(start).substring(0, 2);
        result.add(
          _WeeklyHealthPoint(
            label: label,
            activeEnergyKcal: calories,
            averageHeartRateBpm: avgHr,
          ),
        );
      }
    }

    if (result.isEmpty) {
      final metrics = logs.map(_metricsForHealthChart).toList();
      final calories = metrics.fold<double>(
        0,
        (sum, metric) => sum + (metric.activeEnergyKcal ?? 0),
      );
      final heartRates = metrics
          .map((metric) => metric.heartRateBpm)
          .whereType<double>()
          .toList();
      result.add(
        _WeeklyHealthPoint(
          label: DateFormat('E', locale).format(today).substring(0, 2),
          activeEnergyKcal: calories,
          averageHeartRateBpm: heartRates.isEmpty
              ? null
              : heartRates.fold<double>(0, (sum, hr) => sum + hr) /
                    heartRates.length,
        ),
      );
    }

    return result;
  }
}

class _WeeklyCaloriesChart extends StatelessWidget {
  const _WeeklyCaloriesChart({required this.weeks, this.daily = false});

  final List<_WeeklyHealthPoint> weeks;
  final bool daily;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final maxVal = weeks
        .map((week) => week.activeEnergyKcal)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final latest = weeks.last.activeEnergyKcal;
    final avg = weeks.isEmpty
        ? 0.0
        : weeks.fold<double>(0, (sum, week) => sum + week.activeEnergyKcal) /
              weeks.length;
    final best = maxVal;

    return Column(
      children: [
        SizedBox(
          height: 118,
          child: CustomPaint(
            painter: _WeeklyCaloriesPainter(weeks: weeks, maxValue: maxVal),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.paper.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              _VolumeStat(
                label: daily ? l.heute : l.dieseWoche,
                value: _fmtKcal(latest),
              ),
              _VolumeDivider(),
              _VolumeStat(
                label: daily ? l.avgProTag : l.avgProWoche,
                value: _fmtKcal(avg),
              ),
              if (best > 0) ...[
                _VolumeDivider(),
                _VolumeStat(
                  label: 'Best',
                  value: _fmtKcal(best),
                  color: AppColors.gold,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyHeartRateChart extends StatelessWidget {
  const _WeeklyHeartRateChart({required this.weeks, this.daily = false});

  final List<_WeeklyHealthPoint> weeks;
  final bool daily;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final heartRateWeeks = weeks
        .where((week) => week.averageHeartRateBpm != null)
        .toList();
    final latest = heartRateWeeks.last.averageHeartRateBpm!;
    final avg =
        heartRateWeeks.fold<double>(
          0,
          (sum, week) => sum + week.averageHeartRateBpm!,
        ) /
        heartRateWeeks.length;
    final first = heartRateWeeks.first.averageHeartRateBpm!;
    final delta = latest - first;

    return Column(
      children: [
        SizedBox(
          height: 118,
          child: CustomPaint(
            painter: _WeeklyHeartRatePainter(weeks: weeks),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.paper.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              _VolumeStat(
                label: daily ? l.heute : 'Latest',
                value: _fmtBpm(latest),
              ),
              _VolumeDivider(),
              _VolumeStat(label: 'Avg', value: _fmtBpm(avg)),
              if (delta.abs() >= 0.5) ...[
                _VolumeDivider(),
                _VolumeStat(
                  label: 'Trend',
                  value: '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)}',
                  color: delta <= 0 ? AppColors.sage : AppColors.gold,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyCaloriesPainter extends CustomPainter {
  const _WeeklyCaloriesPainter({required this.weeks, required this.maxValue});

  final List<_WeeklyHealthPoint> weeks;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (weeks.isEmpty) return;
    const padT = 10.0;
    const padB = 22.0;
    final plotH = size.height - padT - padB;
    final slot = size.width / weeks.length;
    final barW = (slot * 0.52).clamp(8.0, 28.0);
    final baseY = padT + plotH;
    final gridPaint = Paint()
      ..color = AppColors.paper.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (final factor in [0.25, 0.5, 0.75]) {
      final y = baseY - plotH * factor;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < weeks.length; i++) {
      final week = weeks[i];
      final xCenter = slot * i + slot / 2;
      final h = maxValue > 0
          ? (week.activeEnergyKcal / maxValue * plotH).clamp(2.0, plotH)
          : 2.0;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(xCenter - barW / 2, baseY - h, barW, h),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      );
      final isLast = i == weeks.length - 1;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            (isLast ? AppColors.gold : AppColors.sage).withValues(alpha: 0.52),
            (isLast ? AppColors.gold : AppColors.sage).withValues(alpha: 0.90),
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
      if (isLast) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = AppColors.gold.withValues(alpha: 0.30)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

    _paintWeekLabels(canvas, size, weeks.map((week) => week.label).toList());
  }

  @override
  bool shouldRepaint(covariant _WeeklyCaloriesPainter old) =>
      old.weeks != weeks || old.maxValue != maxValue;
}

class _WeeklyHeartRatePainter extends CustomPainter {
  const _WeeklyHeartRatePainter({required this.weeks});

  final List<_WeeklyHealthPoint> weeks;

  @override
  void paint(Canvas canvas, Size size) {
    final values = weeks.map((week) => week.averageHeartRateBpm).toList();
    final present = values.whereType<double>().toList();
    if (present.isEmpty) return;

    const padT = 10.0;
    const padB = 22.0;
    final plotH = size.height - padT - padB;
    final minVal = (present.reduce((a, b) => a < b ? a : b) - 5).clamp(
      40.0,
      220.0,
    );
    final maxVal = (present.reduce((a, b) => a > b ? a : b) + 5).clamp(
      minVal + 8,
      230.0,
    );
    final span = maxVal - minVal;
    final slot = weeks.length > 1 ? size.width / (weeks.length - 1) : 0.0;
    final gridPaint = Paint()
      ..color = AppColors.paper.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (final factor in [0.25, 0.5, 0.75]) {
      final y = padT + plotH - plotH * factor;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    Offset pointFor(int i, double value) {
      final x = weeks.length == 1 ? size.width / 2 : i * slot;
      final y = padT + plotH - ((value - minVal) / span) * plotH;
      return Offset(x, y);
    }

    final area = Path();
    final line = Path();
    var started = false;
    var firstX = 0.0;
    var lastX = 0.0;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final p = pointFor(i, value);
      if (!started) {
        line.moveTo(p.dx, p.dy);
        area.moveTo(p.dx, padT + plotH);
        area.lineTo(p.dx, p.dy);
        firstX = p.dx;
        started = true;
      } else {
        line.lineTo(p.dx, p.dy);
        area.lineTo(p.dx, p.dy);
      }
      lastX = p.dx;
    }
    if (started) {
      area.lineTo(lastX, padT + plotH);
      area.lineTo(firstX, padT + plotH);
      area.close();
      canvas.drawPath(
        area,
        Paint()..color = AppColors.coral.withValues(alpha: 0.07),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.coral
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final p = pointFor(i, value);
      canvas.drawCircle(p, 4, Paint()..color = AppColors.bg);
      canvas.drawCircle(p, 4, Paint()..color = AppColors.coral);
    }

    _paintWeekLabels(canvas, size, weeks.map((week) => week.label).toList());
  }

  @override
  bool shouldRepaint(covariant _WeeklyHeartRatePainter old) =>
      old.weeks != weeks;
}

class _WeeklyHealthPoint {
  const _WeeklyHealthPoint({
    required this.label,
    required this.activeEnergyKcal,
    required this.averageHeartRateBpm,
  });

  final String label;
  final double activeEnergyKcal;
  final double? averageHeartRateBpm;
}

LiveHealthMetrics _metricsForHealthChart(WorkoutLog log) {
  final workoutMetrics = log.healthMetrics;
  if (workoutMetrics != null &&
      (workoutMetrics.activeEnergyKcal != null ||
          workoutMetrics.heartRateBpm != null)) {
    return workoutMetrics;
  }

  final snapshots = log.exerciseTimings
      .map((timing) => timing.healthSnapshot)
      .whereType<LiveHealthMetrics>()
      .toList();
  final calories = snapshots.fold<double>(
    0,
    (sum, metric) => sum + (metric.activeEnergyKcal ?? 0),
  );
  final heartRates = snapshots
      .map((metric) => metric.heartRateBpm)
      .whereType<double>()
      .toList();
  return LiveHealthMetrics(
    updatedAt: log.completedAt ?? log.startedAt,
    sampleCount: snapshots.fold<int>(0, (sum, m) => sum + m.sampleCount),
    activeEnergyKcal: calories > 0 ? calories : null,
    heartRateBpm: heartRates.isEmpty
        ? null
        : heartRates.fold<double>(0, (sum, hr) => sum + hr) / heartRates.length,
  );
}

void _paintWeekLabels(Canvas canvas, Size size, List<String> labels) {
  if (labels.isEmpty) return;
  final textPainter = TextPainter(textDirection: TextDirection.ltr);
  final slot = labels.length > 1 ? size.width / (labels.length - 1) : 0.0;
  for (var i = 0; i < labels.length; i++) {
    final x = labels.length == 1 ? size.width / 2 : i * slot;
    final isLast = i == labels.length - 1;
    textPainter.text = TextSpan(
      text: labels[i],
      style: TextStyle(
        fontSize: 9,
        fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
        color: isLast
            ? AppColors.sage
            : AppColors.paper.withValues(alpha: 0.28),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (x - textPainter.width / 2).clamp(0, size.width - textPainter.width),
        size.height - 13,
      ),
    );
  }
}

String _fmtKcal(double value) => '${value.round()} kcal';

String _fmtBpm(double value) => '${value.round()} bpm';

// ── Strength PRs ─────────────────────────────────────────────────────────────

class _StrengthPRs extends StatefulWidget {
  const _StrengthPRs({required this.controller, required this.logs});

  final dynamic controller;
  final List<WorkoutLog> logs;

  @override
  State<_StrengthPRs> createState() => _StrengthPRsState();
}

class _StrengthPRsState extends State<_StrengthPRs> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final data = widget.controller.data as FitnessData;
    final prs = data.personalRecords;
    final visible = _expanded ? prs : prs.take(4).toList();
    final hasMore = prs.length > 4;
    final contextCount = prs.where((pr) => pr.includeInContext).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.staerkePRsLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: AppColors.paper.withValues(alpha: 0.28),
                ),
              ),
            ),
            if (contextCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  l.imKontext(contextCount),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sage.withValues(alpha: 0.65),
                  ),
                ),
              ),
            if (hasMore)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? l.weniger : l.mehrAnzeigen(prs.length - 4),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sage,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++)
                _PRRow(
                  pr: visible[i],
                  isLast: i == visible.length - 1,
                  onEdit: () => _showPRDialog(
                    context,
                    widget.controller,
                    existing: visible[i],
                  ),
                  onToggleContext: () =>
                      widget.controller.togglePersonalRecordContext(
                        visible[i].id,
                        !visible[i].includeInContext,
                      ),
                  onDelete: () =>
                      widget.controller.deletePersonalRecord(visible[i].id),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showPRDialog(context, widget.controller),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.28)),
            ),
            child: Text(
              l.prHinzufuegen,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.sage,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PRRow extends StatelessWidget {
  const _PRRow({
    required this.pr,
    required this.isLast,
    required this.onEdit,
    required this.onToggleContext,
    required this.onDelete,
  });

  final PersonalRecord pr;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onToggleContext;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kgStr = pr.weightKg == pr.weightKg.roundToDouble()
        ? '${pr.weightKg.toInt()} kg'
        : '${pr.weightKg} kg';

    return GestureDetector(
      onTap: onEdit,
      onLongPress: onDelete,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.paper.withValues(alpha: 0.06),
                  ),
                ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggleContext,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: pr.includeInContext
                      ? AppColors.sage.withValues(alpha: 0.15)
                      : AppColors.paper.withValues(alpha: 0.05),
                  border: Border.all(
                    color: pr.includeInContext
                        ? AppColors.sage.withValues(alpha: 0.40)
                        : AppColors.paper.withValues(alpha: 0.15),
                  ),
                ),
                child: pr.includeInContext
                    ? const Icon(Icons.check, size: 13, color: AppColors.sage)
                    : null,
              ),
            ),
            Expanded(
              child: Text(
                pr.exerciseName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.paper,
                ),
              ),
            ),
            if (pr.delta.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.sage.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  pr.delta,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sage.withValues(alpha: 0.80),
                  ),
                ),
              ),
            SizedBox(
              width: 70,
              child: Text(
                kgStr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'RussoOne',
                  fontSize: 18,
                  color: AppColors.paper,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showPRDialog(
  BuildContext context,
  dynamic controller, {
  PersonalRecord? existing,
}) async {
  final name = TextEditingController(text: existing?.exerciseName ?? '');
  final weight = TextEditingController(
    text: existing != null ? existing.weightKg.toString() : '',
  );
  final previous = TextEditingController(
    text: existing?.previousKg?.toString() ?? '',
  );
  var includeInContext = existing?.includeInContext ?? true;

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(
            existing == null ? l.prHinzufuegenTitle : l.prBearbeitenTitle,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: l.uebungLabel),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: weight,
                  decoration: InputDecoration(
                    labelText: l.gewichtKgLabel,
                    hintText: l.gewichtKgHint,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: previous,
                  decoration: InputDecoration(
                    labelText: l.vorherigesGewichtLabel,
                    hintText: l.optionalHint,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.imCoachKontextSenden),
                  subtitle: Text(
                    l.imCoachKontextSendenSub,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.paper.withValues(alpha: 0.45),
                    ),
                  ),
                  value: includeInContext,
                  onChanged: (v) => setState(() => includeInContext = v),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.coral),
                onPressed: () {
                  controller.deletePersonalRecord(existing.id);
                  Navigator.pop(context);
                },
                child: Text(l.tooltipLoeschen),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.btnAbbrechen),
            ),
            FilledButton(
              onPressed: () {
                final kg = double.tryParse(weight.text.replaceAll(',', '.'));
                if (name.text.trim().isEmpty || kg == null || kg <= 0) return;
                final prev = double.tryParse(
                  previous.text.replaceAll(',', '.'),
                );
                if (existing == null) {
                  controller.addPersonalRecord(
                    exerciseName: name.text,
                    weightKg: kg,
                    previousKg: prev,
                    includeInContext: includeInContext,
                  );
                } else {
                  controller.updatePersonalRecord(
                    existing.copyWith(
                      exerciseName: name.text.trim(),
                      weightKg: kg,
                      previousKg: prev,
                      clearPreviousKg: previous.text.trim().isEmpty,
                      includeInContext: includeInContext,
                    ),
                  );
                }
                Navigator.pop(context);
              },
              child: Text(l.btnSpeichern),
            ),
          ],
        );
      },
    ),
  );
}

// ── Readiness / Soreness Chart ───────────────────────────────────────────────

class _ReadinessChart extends StatelessWidget {
  const _ReadinessChart({required this.logs});

  final List<WorkoutLog> logs;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final recentLogs = logs
        .where((l) => l.completedAt != null && l.readiness > 0)
        .toList();
    if (recentLogs.isEmpty) return const SizedBox.shrink();

    final last7 = recentLogs.length > 7
        ? recentLogs.sublist(recentLogs.length - 7)
        : recentLogs;
    final readiness = last7.map((l) => l.readiness).toList();
    final soreness = last7.map((l) => l.soreness).toList();
    final avgReadiness =
        readiness.fold<int>(0, (a, b) => a + b) / readiness.length;
    final avgSoreness =
        soreness.fold<int>(0, (a, b) => a + b) / soreness.length;
    final labels = last7
        .map((l) => DateFormat('E', locale).format(l.startedAt).substring(0, 2))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.bereitschaftSessions(readiness.length),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: AppColors.paper.withValues(alpha: 0.28),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              // Legend
              Row(
                children: [
                  _ChartLegend(
                    color: AppColors.sage,
                    label: loc.bereitschaftLabel,
                  ),
                  const SizedBox(width: 16),
                  _ChartLegend(
                    color: AppColors.coral,
                    label: loc.erschoepfungLabel,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Chart
              SizedBox(
                height: 72,
                child: CustomPaint(
                  size: const Size(double.infinity, 72),
                  painter: _ReadinessPainter(
                    readiness: readiness,
                    soreness: soreness,
                    labels: labels,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Summary
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.paper.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ReadinessSummary(
                        label: loc.avgBereitschaft,
                        value: avgReadiness,
                        color: AppColors.sage,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: AppColors.paper.withValues(alpha: 0.06),
                    ),
                    Expanded(
                      child: _ReadinessSummary(
                        label: loc.avgErschoepfung,
                        value: avgSoreness,
                        color: AppColors.coral,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2.5,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppColors.paper.withValues(alpha: 0.38),
          ),
        ),
      ],
    );
  }
}

class _ReadinessSummary extends StatelessWidget {
  const _ReadinessSummary({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.paper.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: 'RussoOne',
                  fontSize: 18,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 6),
              for (var n = 1; n <= 5; n++)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1.5),
                    color: n <= value.round()
                        ? color.withValues(alpha: 0.70)
                        : AppColors.paper.withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessPainter extends CustomPainter {
  _ReadinessPainter({
    required this.readiness,
    required this.soreness,
    required this.labels,
  });

  final List<int> readiness;
  final List<int> soreness;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (readiness.isEmpty) return;
    const padT = 8.0;
    const padB = 20.0;
    final plotH = size.height - padT - padB;
    final n = readiness.length;
    final xStep = n > 1 ? size.width / (n - 1) : size.width / 2;

    // Grid lines at 2, 3, 4
    final gridPaint = Paint()
      ..color = const Color(0x0FEEECEA)
      ..strokeWidth = 1;
    for (final v in [2, 3, 4]) {
      final y = padT + plotH - ((v - 1) / 4) * plotH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Area fill for readiness
    final areaPath = Path();
    for (var i = 0; i < n; i++) {
      final x = i * xStep;
      final y = padT + plotH - ((readiness[i] - 1) / 4) * plotH;
      if (i == 0) {
        areaPath.moveTo(x, y);
      } else {
        areaPath.lineTo(x, y);
      }
    }
    areaPath.lineTo((n - 1) * xStep, padT + plotH);
    areaPath.lineTo(0, padT + plotH);
    areaPath.close();
    canvas.drawPath(
      areaPath,
      Paint()..color = AppColors.sage.withValues(alpha: 0.08),
    );

    // Soreness line
    final sorenessPath = Path();
    for (var i = 0; i < n; i++) {
      final x = i * xStep;
      final y = padT + plotH - ((soreness[i] - 1) / 4) * plotH;
      if (i == 0) {
        sorenessPath.moveTo(x, y);
      } else {
        sorenessPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      sorenessPath,
      Paint()
        ..color = AppColors.coral.withValues(alpha: 0.55)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Readiness line
    final readPath = Path();
    for (var i = 0; i < n; i++) {
      final x = i * xStep;
      final y = padT + plotH - ((readiness[i] - 1) / 4) * plotH;
      if (i == 0) {
        readPath.moveTo(x, y);
      } else {
        readPath.lineTo(x, y);
      }
    }
    canvas.drawPath(
      readPath,
      Paint()
        ..color = AppColors.sage
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Dots on readiness
    for (var i = 0; i < n; i++) {
      final x = i * xStep;
      final y = padT + plotH - ((readiness[i] - 1) / 4) * plotH;
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = AppColors.bg);
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..color = AppColors.sage
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // X-axis labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < n && i < labels.length; i++) {
      final x = i * xStep;
      final isLast = i == n - 1;
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontSize: 9,
          fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
          color: isLast
              ? AppColors.sage
              : AppColors.paper.withValues(alpha: 0.28),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - 12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ReadinessPainter old) =>
      old.readiness != readiness || old.soreness != soreness;
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              color: AppColors.paper.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.controller});

  final dynamic controller;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  late final TextEditingController _bridgeUrlController;
  late final TextEditingController _bridgeTokenController;
  bool _bridgeBusy = false;
  bool _handoffCopied = false;
  bool _healthConnected = false;

  @override
  void initState() {
    super.initState();
    _bridgeUrlController = TextEditingController(
      text: widget.controller.bridgeConfig.baseUrl,
    );
    _bridgeTokenController = TextEditingController(
      text: widget.controller.bridgeConfig.token,
    );
  }

  @override
  void dispose() {
    _bridgeUrlController.dispose();
    _bridgeTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.controller.bridgeConfig as LocalBridgeConfig;

    return ColoredBox(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 22, 14, 48),
        children: [
          _SettingsAppleHealthCard(
            connected: _healthConnected,
            onToggle: _toggleHealth,
          ),
          const SizedBox(height: 24),
          _SettingsAgentHandoffCard(
            copied: _handoffCopied,
            onCopy: _handleHandoff,
          ),
          const SizedBox(height: 24),
          _SettingsServerCard(
            urlController: _bridgeUrlController,
            tokenController: _bridgeTokenController,
            isConnected: config.isConfigured,
            isBusy: _bridgeBusy,
            serverUrl: config.baseUrl,
            onConnect: _connectServer,
            onDisconnect: _disconnectServer,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleHealth() async {
    if (_healthConnected) {
      setState(() => _healthConnected = false);
      return;
    }
    await widget.controller.connectHealth();
    if (!mounted) return;
    final status = widget.controller.status as String;
    setState(() {
      _healthConnected = status.contains('connected');
    });
  }

  Future<void> _handleHandoff() async {
    final payload = _agentHandoffPayload();
    await Clipboard.setData(ClipboardData(text: payload));
    setState(() => _handoffCopied = true);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _handoffCopied = false);
    });
  }

  Future<void> _connectServer() async {
    if (_bridgeBusy) return;
    setState(() => _bridgeBusy = true);
    try {
      await widget.controller.saveBridgeConfig(
        baseUrl: _bridgeUrlController.text,
        token: _bridgeTokenController.text,
      );
      await widget.controller.testBridgeConnection();
    } finally {
      if (mounted) setState(() => _bridgeBusy = false);
    }
  }

  Future<void> _disconnectServer() async {
    _bridgeUrlController.clear();
    _bridgeTokenController.clear();
    await widget.controller.saveBridgeConfig(baseUrl: '', token: '');
    if (mounted) setState(() {});
  }
}

// ─── Settings Section Label ──────────────────────────────────────────────────
class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
          color: AppColors.paper.withValues(alpha: 0.32),
        ),
      ),
    );
  }
}

// ─── Apple Health Card ───────────────────────────────────────────────────────
class _SettingsAppleHealthCard extends StatelessWidget {
  const _SettingsAppleHealthCard({
    required this.connected,
    required this.onToggle,
  });

  final bool connected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = connected ? AppColors.sage : AppColors.coral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsSectionLabel(label: 'Apple Health'),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: connected
                  ? AppColors.sage.withValues(alpha: 0.20)
                  : AppColors.paper.withValues(alpha: AppOpacity.hairline),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: connected ? 0.12 : 0.10),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: accent.withValues(
                          alpha: connected ? 0.22 : 0.20,
                        ),
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.heart_fill,
                      size: 22,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Apple Health',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.paper,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 300),
                          style: TextStyle(
                            fontSize: 12,
                            color: connected
                                ? AppColors.sage.withValues(alpha: 0.80)
                                : AppColors.paper.withValues(alpha: 0.40),
                          ),
                          child: Text(
                            connected
                                ? 'Verbunden · Trainingsdaten aktiv'
                                : 'Nicht verbunden',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SettingsToggle(value: connected, onTap: onToggle),
                ],
              ),
              if (connected) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppColors.sage.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (final entry in [
                        ('Workouts', 'Lesen'),
                        ('Herzfrequenz', 'Lesen'),
                        ('Körper', 'Lesen + Schreiben'),
                      ])
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.$1.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: AppColors.sage.withValues(alpha: 0.60),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                entry.$2,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.paper.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Toggle Switch ───────────────────────────────────────────────────────────
class _SettingsToggle extends StatelessWidget {
  const _SettingsToggle({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: value
              ? AppColors.sage
              : AppColors.paper.withValues(alpha: 0.12),
          border: Border.all(
            color: value
                ? AppColors.sage
                : AppColors.paper.withValues(alpha: 0.14),
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? AppColors.bg
                  : AppColors.paper.withValues(alpha: 0.55),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Agent Handoff Card ──────────────────────────────────────────────────────
class _SettingsAgentHandoffCard extends StatelessWidget {
  const _SettingsAgentHandoffCard({required this.copied, required this.onCopy});

  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsSectionLabel(label: 'Coach Agent'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: copied
                  ? AppColors.sage.withValues(alpha: 0.22)
                  : AppColors.paper.withValues(alpha: AppOpacity.hairline),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kopiert den vollständigen Kontext-Snapshot in die '
                'Zwischenablage — bereit zum Einfügen in deinen '
                'Coach-Agent.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.65,
                  color: AppColors.paper.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: copied
                        ? AppColors.sage.withValues(alpha: 0.12)
                        : null,
                    gradient: copied
                        ? null
                        : const LinearGradient(
                            begin: Alignment(-0.6, -1),
                            end: Alignment(0.6, 1),
                            colors: [Color(0xFF1D4A35), AppColors.sage],
                          ),
                    border: copied
                        ? Border.all(
                            color: AppColors.sage.withValues(alpha: 0.28),
                          )
                        : null,
                  ),
                  child: Material(
                    color: AppColors.transparent,
                    child: InkWell(
                      onTap: copied ? null : onCopy,
                      borderRadius: BorderRadius.circular(13),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              copied ? Icons.check : CupertinoIcons.doc_on_doc,
                              size: 16,
                              color: copied ? AppColors.sage : AppColors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              copied ? 'KOPIERT' : 'IN ZWISCHENABLAGE KOPIEREN',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: copied
                                    ? AppColors.sage
                                    : AppColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Server Setup Card ───────────────────────────────────────────────────────
class _SettingsServerCard extends StatefulWidget {
  const _SettingsServerCard({
    required this.urlController,
    required this.tokenController,
    required this.isConnected,
    required this.isBusy,
    required this.serverUrl,
    required this.onConnect,
    required this.onDisconnect,
  });

  final TextEditingController urlController;
  final TextEditingController tokenController;
  final bool isConnected;
  final bool isBusy;
  final String serverUrl;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  State<_SettingsServerCard> createState() => _SettingsServerCardState();
}

class _SettingsServerCardState extends State<_SettingsServerCard> {
  String? _focusedField;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SettingsSectionLabel(label: 'App verbinden'),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isConnected
                  ? AppColors.sage.withValues(alpha: 0.20)
                  : AppColors.paper.withValues(alpha: AppOpacity.hairline),
            ),
          ),
          child: widget.isBusy
              ? _buildConnecting()
              : widget.isConnected
              ? _buildConnected()
              : _buildSetup(),
        ),
      ],
    );
  }

  Widget _buildSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsPairField(
          label: 'SERVER URL',
          placeholder: 'http://192.168.1.42:8787',
          controller: widget.urlController,
          mono: true,
          focused: _focusedField == 'url',
          onFocusChange: (f) =>
              setState(() => _focusedField = f ? 'url' : null),
        ),
        const SizedBox(height: 10),
        _SettingsPairField(
          label: 'API KEY',
          placeholder: 'sk-t4l-…',
          controller: widget.tokenController,
          mono: true,
          focused: _focusedField == 'token',
          onFocusChange: (f) =>
              setState(() => _focusedField = f ? 'token' : null),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Material(
            color: AppColors.sage,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onConnect,
              borderRadius: BorderRadius.circular(12),
              child: const Center(
                child: Text(
                  'VERBINDEN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnecting() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.sage,
              backgroundColor: AppColors.sage.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Verbinde…',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.paper.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnected() {
    final displayUrl = widget.serverUrl.isNotEmpty
        ? widget.serverUrl
        : 'Server';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.sage.withValues(alpha: 0.35),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.sage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayUrl,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: AppColors.sage.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Text(
                'ONLINE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.sage.withValues(alpha: 0.60),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: widget.onDisconnect,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.paper.withValues(alpha: 0.09),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Verbindung trennen',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.paper.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pair Input Field ────────────────────────────────────────────────────────
class _SettingsPairField extends StatelessWidget {
  const _SettingsPairField({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.mono = false,
    this.focused = false,
    required this.onFocusChange,
  });

  final String label;
  final String placeholder;
  final TextEditingController controller;
  final bool mono;
  final bool focused;
  final ValueChanged<bool> onFocusChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.paper.withValues(alpha: 0.32),
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: AppColors.paper.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused
                  ? AppColors.sage.withValues(alpha: 0.45)
                  : AppColors.paper.withValues(alpha: 0.10),
            ),
          ),
          alignment: Alignment.center,
          child: Focus(
            onFocusChange: onFocusChange,
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontSize: mono ? 12 : 14,
                fontFamily: mono ? 'monospace' : null,
                color: AppColors.paper,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: TextStyle(
                  color: AppColors.paper.withValues(alpha: 0.25),
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final label = _compactStatusLabel(text);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: AppOpacity.wash),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        children: [
          Icon(label.$2, size: 15, color: label.$3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.$1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

(String, IconData, Color) _compactStatusLabel(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return ('Bereit', CupertinoIcons.check_mark_circled, AppColors.sage);
  }
  final lower = text.toLowerCase();
  if (lower.contains('failed') ||
      lower.contains('error') ||
      lower.contains('denied') ||
      lower.contains('invalid')) {
    return (
      'Aktion fehlgeschlagen',
      CupertinoIcons.exclamationmark_triangle,
      AppColors.coral,
    );
  }
  if (lower.contains('exported')) {
    return (
      'Context exportiert',
      CupertinoIcons.square_arrow_up,
      AppColors.sage,
    );
  }
  if (lower.contains('imported') || lower.contains('accepted')) {
    return (
      'Import abgeschlossen',
      CupertinoIcons.check_mark_circled,
      AppColors.sage,
    );
  }
  if (lower.contains('new t4l gym bro training block')) {
    return ('Neuer Block bereit', CupertinoIcons.bell_fill, AppColors.coral);
  }
  if (lower.contains('no t4l gym bro training block')) {
    return ('Kein neuer Block', CupertinoIcons.doc_text_search, AppColors.gold);
  }
  if (lower.contains('workout started')) {
    return ('Workout aktiv', CupertinoIcons.play_circle_fill, AppColors.coral);
  }
  if (lower.contains('local-first coaching data loaded')) {
    return ('Lokal geladen', CupertinoIcons.check_mark_circled, AppColors.sage);
  }
  if (text.length > 42 || text.contains('/')) {
    return ('Status aktualisiert', CupertinoIcons.info_circle, AppColors.sage);
  }
  return (text, CupertinoIcons.info_circle, AppColors.sage);
}

String _agentHandoffPayload() {
  return '''
You are my T4L Gym Bro coaching agent.

Agent instructions repo:
$_agentInstructionsRepo

Server install command:
$_bridgeInstallCommand

Server start command:
$_bridgeServeCommand

Please read the agent instructions repo and follow the adapter for your runtime.
'''
      .trim();
}

class _CoachBlockAvailableBanner extends StatelessWidget {
  const _CoachBlockAvailableBanner({required this.controller});

  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.small,
      ),
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: AppOpacity.tint),
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(
          color: scheme.secondary.withValues(alpha: AppOpacity.borderTint),
        ),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.bell_fill, color: scheme.secondary),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.neuerCoachBlock,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: controller.importCoachBlockPlan,
            icon: const Icon(CupertinoIcons.arrow_down_doc),
            label: Text(AppLocalizations.of(context)!.btnImport),
          ),
        ],
      ),
    );
  }
}

Future<void> _handleExerciseStop(
  BuildContext context,
  dynamic controller,
  ExercisePrescription exercise,
) async {
  // Stop the timer first (so duration is final) but keep the workout
  // open so any "last exercise → summary" auto-close waits until the
  // user has logged the sets for this exercise.
  await controller.stopExerciseTimer(
    exercise.exerciseId,
    autoCloseWorkout: false,
  );

  if (!context.mounted) return;

  // Prefill from the previously-logged set on this exercise (if any),
  // otherwise from the prescription.
  final activeLog = controller.activeWorkoutLog as WorkoutLog?;
  var history = activeLog == null
      ? <LoggedSet>[]
      : activeLog.sets
            .where((s) => s.exerciseId == exercise.exerciseId)
            .toList();

  final prescribedRepsMatch = RegExp(
    r'\d+',
  ).firstMatch(exercise.reps)?.group(0);
  final prescribedWeightMatch = RegExp(
    r'(\d+(?:[.,]\d+)?)',
  ).firstMatch(exercise.targetLoad);
  final double fallbackWeight = prescribedWeightMatch != null
      ? (double.tryParse(
              prescribedWeightMatch.group(1)!.replaceAll(',', '.'),
            ) ??
            20.0)
      : 20.0;
  final fallbackReps = int.tryParse(prescribedRepsMatch ?? '') ?? 8;

  while (context.mounted) {
    final logged = history.length;
    if (logged >= exercise.sets) break;
    final initWeight = history.isNotEmpty
        ? history.last.weightKg
        : fallbackWeight;
    final initReps = history.isNotEmpty ? history.last.reps : fallbackReps;

    if (!context.mounted) break;
    final timing = controller.timingForExercise(exercise.exerciseId) as ExerciseTiming?;
    final elapsedDuration = timing?.durationSeconds;

    // ignore: use_build_context_synchronously
    final result = await showSetLogModal(
      context,
      exerciseName: exercise.name,
      currentSetNumber: logged + 1,
      totalSets: exercise.sets,
      initialWeightKg: initWeight,
      initialReps: initReps,
      initialRpe: exercise.targetRpe,
      targetReps: int.tryParse(prescribedRepsMatch ?? ''),
      targetRpe: exercise.targetRpe,
      trackingMode: exercise.trackingMode,
      targetDurationSeconds: exercise.targetDurationSeconds,
      initialDurationSeconds: elapsedDuration,
      history: history,
    );
    if (result == null || result.delete) break;
    await controller.logSet(
      exercise,
      result.weightKg,
      result.reps,
      result.rpe,
      durationSeconds: result.durationSeconds,
    );
    // Refresh from controller to get the freshly appended set.
    final refreshedLog = controller.activeWorkoutLog as WorkoutLog?;
    history = refreshedLog == null
        ? history
        : refreshedLog.sets
              .where((s) => s.exerciseId == exercise.exerciseId)
              .toList();
  }

  // Now run the auto-close check the controller deferred.
  await controller.tryAutoCloseWorkout();
}

Future<void> _showSetDialog(
  BuildContext context,
  dynamic controller,
  ExercisePrescription exercise,
) async {
  final activeLog = controller.activeWorkoutLog as WorkoutLog?;
  final history = activeLog == null
      ? const <LoggedSet>[]
      : activeLog.sets
            .where((s) => s.exerciseId == exercise.exerciseId)
            .toList();
  final currentSetNumber = history.length + 1;

  // Try to infer a starting weight from the prescription's targetLoad
  // (e.g. "80 kg" or "100"). Falls back to the last logged set on this
  // exercise, then to 20 kg.
  double initialWeight;
  if (history.isNotEmpty) {
    initialWeight = history.last.weightKg;
  } else {
    final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(exercise.targetLoad);
    initialWeight = match != null
        ? double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 20
        : 20;
  }

  final initialReps = history.isNotEmpty
      ? history.last.reps
      : (int.tryParse(
              RegExp(r'\d+').firstMatch(exercise.reps)?.group(0) ?? '',
            ) ??
            8);

  final result = await showSetLogModal(
    context,
    exerciseName: exercise.name,
    currentSetNumber: currentSetNumber,
    totalSets: exercise.sets,
    initialWeightKg: initialWeight,
    initialReps: initialReps,
    initialRpe: exercise.targetRpe,
    targetReps: int.tryParse(
      RegExp(r'\d+').firstMatch(exercise.reps)?.group(0) ?? '',
    ),
    targetRpe: exercise.targetRpe,
    trackingMode: exercise.trackingMode,
    targetDurationSeconds: exercise.targetDurationSeconds,
    history: history,
  );
  if (result == null || result.delete) return;
  await controller.logSet(
    exercise,
    result.weightKg,
    result.reps,
    result.rpe,
    durationSeconds: result.durationSeconds,
  );
}

Future<void> _showMemoryDialog(
  BuildContext context,
  dynamic controller, {
  MemoryEntry? existing,
}) async {
  var category = existing?.category ?? MemoryCategory.training;
  var active = existing?.active ?? true;
  final title = TextEditingController(text: existing?.title ?? '');
  final summary = TextEditingController(text: existing?.summary ?? '');
  final markdown = TextEditingController(text: existing?.markdown ?? '');
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(
            existing == null ? l.dialogMemoryAddTitle : l.dialogMemoryEditTitle,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MemoryCategory>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: l.dialogMemoryKategorie,
                  ),
                  items: [
                    for (final item in MemoryCategory.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => category = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: l.dialogMemoryTitel),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: summary,
                  decoration: InputDecoration(
                    labelText: l.dialogMemoryKurzMemory,
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: markdown,
                  decoration: InputDecoration(
                    labelText: l.dialogMemoryMarkdown,
                  ),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.dialogMemoryAktivFuerCoach),
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.btnAbbrechen),
            ),
            FilledButton(
              onPressed: () {
                if (existing == null) {
                  controller.addMemory(
                    category: category,
                    title: title.text,
                    summary: summary.text,
                    markdown: markdown.text,
                    active: active,
                  );
                } else {
                  controller.updateMemory(
                    existing.copyWith(
                      category: category,
                      title: title.text,
                      summary: summary.text,
                      markdown: markdown.text,
                      active: active,
                    ),
                  );
                }
                Navigator.pop(context);
              },
              child: Text(l.btnSpeichern),
            ),
          ],
        );
      },
    ),
  );
}

// ignore: unused_element
Future<void> _showMealAnalysisDialog(
  BuildContext context,
  dynamic controller,
) async {
  final description = TextEditingController();
  String? imagePath;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final l = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l.dialogMealAnalysisTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: description,
                  decoration: InputDecoration(
                    labelText: l.dialogMealAnalysisWhat,
                    hintText: l.dialogMealAnalysisHint,
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                if (imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(imagePath!),
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final path = await controller
                              .pickMealImageFromGallery();
                          if (path != null) setState(() => imagePath = path);
                        },
                        icon: const Icon(CupertinoIcons.photo),
                        label: Text(l.btnFoto),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final path = await controller
                              .pickMealImageFromCamera();
                          if (path != null) setState(() => imagePath = path);
                        },
                        icon: const Icon(CupertinoIcons.camera),
                        label: Text(l.btnKamera),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.btnAbbrechen),
            ),
            FilledButton(
              onPressed: () {
                controller.exportNutritionAnalysisRequest(
                  description: description.text,
                  imagePath: imagePath,
                );
                Navigator.pop(context);
              },
              child: Text(l.btnAnCoachSenden),
            ),
          ],
        );
      },
    ),
  );
}

// ignore: unused_element
Future<void> _showMealResultDialog(
  BuildContext context,
  dynamic controller,
  MealAnalysisResult result,
) async {
  final calories = TextEditingController(text: result.calories.toString());
  final protein = TextEditingController(text: result.protein.toString());
  final carbs = TextEditingController(text: result.carbs.toString());
  final fat = TextEditingController(text: result.fat.toString());
  final weight = TextEditingController(
    text: result.bodyWeightKg.toStringAsFixed(1),
  );
  final notes = TextEditingController(text: result.correctionNotes);
  await showDialog<void>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l.dialogMealResultTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.mealDescription),
              if (result.assumptions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Assumptions: ${result.assumptions.join(', ')}'),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: calories,
                decoration: InputDecoration(
                  labelText: l.dialogMealResultKalorien,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: protein,
                decoration: InputDecoration(
                  labelText: l.dialogMealResultProtein,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: carbs,
                decoration: InputDecoration(labelText: l.dialogMealResultCarbs),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fat,
                decoration: InputDecoration(labelText: l.dialogMealResultFett),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weight,
                decoration: InputDecoration(
                  labelText: l.dialogMealResultKoerpergewicht,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                decoration: InputDecoration(
                  labelText: l.dialogMealResultKorrektur,
                ),
                minLines: 2,
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.discardMealAnalysis();
              Navigator.pop(context);
            },
            child: Text(l.btnVerwerfen),
          ),
          FilledButton(
            onPressed: () {
              controller.acceptMealAnalysis(
                calories: int.tryParse(calories.text) ?? result.calories,
                protein: int.tryParse(protein.text) ?? result.protein,
                carbs: int.tryParse(carbs.text) ?? result.carbs,
                fat: int.tryParse(fat.text) ?? result.fat,
                bodyWeightKg:
                    double.tryParse(weight.text.replaceAll(',', '.')) ??
                    result.bodyWeightKg,
                notes: notes.text,
              );
              Navigator.pop(context);
            },
            child: Text(l.btnSpeichern),
          ),
        ],
      );
    },
  );
}

Future<void> _showProfileDialog(
  BuildContext context,
  dynamic controller,
  AthleteProfile profile,
) async {
  final height = TextEditingController(
    text: profile.heightCm.toStringAsFixed(0),
  );
  final weight = TextEditingController(
    text: profile.weightKg.toStringAsFixed(1),
  );
  final age = TextEditingController(text: profile.age.toString());
  final sex = TextEditingController(text: profile.sex);
  final goal = TextEditingController(text: profile.goal);
  await showDialog<void>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context)!;
      return AlertDialog(
        title: Text(l.dialogProfileTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: goal,
                decoration: InputDecoration(
                  labelText: l.dialogProfileTrainingsziel,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: height,
                decoration: InputDecoration(labelText: l.dialogProfileGroesse),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: weight,
                decoration: InputDecoration(labelText: l.dialogProfileGewicht),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: age,
                decoration: InputDecoration(labelText: l.dialogProfileAlter),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sex,
                decoration: InputDecoration(labelText: l.dialogProfileSex),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.btnAbbrechen),
          ),
          FilledButton(
            onPressed: () {
              controller.updateProfile(
                profile.copyWith(
                  goal: goal.text,
                  heightCm:
                      double.tryParse(height.text.replaceAll(',', '.')) ??
                      profile.heightCm,
                  weightKg:
                      double.tryParse(weight.text.replaceAll(',', '.')) ??
                      profile.weightKg,
                  age: int.tryParse(age.text) ?? profile.age,
                  sex: sex.text,
                ),
              );
              Navigator.pop(context);
            },
            child: Text(l.btnSpeichern),
          ),
        ],
      );
    },
  );
}
