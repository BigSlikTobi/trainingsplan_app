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
import '../state/fitness_controller.dart';
import '../util/haptics.dart';
import 'chat_screen.dart';
import 'set_log_modal.dart';
import 'today_hero_card.dart';
import 'workout_summary_screen.dart';

part 'dashboard_nutrition.dart';
part 'dashboard_coach.dart';
part 'dashboard_progress.dart';

const _agentInstructionsRepo =
    'https://github.com/BigSlikTobi/t4l-agent-instructions';
const _bridgeInstallCommand = 'pipx install t4l-server';
const _bridgeServeCommand = 't4l-server serve --data-dir ~/T4LServerData';

/// Opens the in-app coach chat as a full-screen route, re-providing the
/// controller so the chat surface (and anything it pushes) keeps app state.
void _openCoachChat(BuildContext context, FitnessController controller) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FitnessScope(
        controller: controller,
        child: ChatScreen(controller: controller),
      ),
    ),
  );
}

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
            tooltip: l.chatOpenTooltip,
            onPressed: () => _openCoachChat(context, controller),
            icon: const Icon(CupertinoIcons.chat_bubble_2),
          ),
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

  final FitnessController controller;

  @override
  Widget build(BuildContext context) {
    final workout = controller.nextWorkout;
    final block = controller.activeBlock;
    final data = controller.data;
    // If today's session is already done, keep showing it (summary + set
    // logging / comments) rather than presenting a workout to train again.
    // Derived from the logs by date, so a session finished earlier today — on
    // the phone or the watch, even in a previous app launch — is recognised,
    // and it clears itself once the day rolls over.
    final completedToday = controller.todaysCompletedWorkout;
    if (completedToday != null) {
      return ColoredBox(
        color: AppColors.bg,
        child: WorkoutSummaryView(logId: completedToday.id),
      );
    }
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
    final activeLog = controller.activeWorkoutLog;
    final hasActiveWorkout = activeLog != null;
    final sessionIsPaused = controller.sessionIsPaused;

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
      if (controller.isExerciseRunning(ex.exerciseId)) {
        focusedExercise = ex;
        focusedIndex = i + 1;
        focusedIsPaused = false;
        break;
      }
    }
    if (focusedExercise == null) {
      for (var i = 0; i < workout.exercises.length; i++) {
        final ex = workout.exercises[i];
        if (controller.isExercisePaused(ex.exerciseId)) {
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
            sessionElapsed: controller.activeSessionElapsed,
            avgRpe: avgRpe,
            focusedExercise: focusedExercise,
            focusedExerciseIndex: focusedIndex,
            focusedExerciseElapsed: focusedExercise == null
                ? null
                : controller.elapsedForExercise(focusedExercise.exerciseId),
            focusedExerciseIsPaused: focusedIsPaused,
            canDismissFocus: focusedIsPaused,
            totalExercises: workout.exercises.length,
            onStart: () {
              Haptics.action();
              controller.startCurrentWorkout();
            },
            onComplete: () {
              Haptics.success();
              controller.completeCurrentWorkout();
            },
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
  final FitnessController controller;
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
        controller.timingForExercise(exercise.exerciseId);
    final isRunning = controller.isExerciseRunning(exercise.exerciseId);
    final isPaused = controller.isExercisePaused(exercise.exerciseId);
    final isStopped = controller.isExerciseStopped(exercise.exerciseId);
    final durationSeconds = timing?.durationSeconds;
    final elapsed = isStopped && durationSeconds != null
        ? Duration(seconds: durationSeconds)
        : controller.elapsedForExercise(exercise.exerciseId);
    final liveMetrics = controller.liveHealthMetrics;
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
  FitnessController controller,
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

  final FitnessController controller;

  @override
  Widget build(BuildContext context) {
    final isConnected =
        controller.bridgeConfig.isConfigured;
    final block = controller.activeBlock;
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

// ─── Settings Screen ────────────────────────────────────────────────────────

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.controller});

  final FitnessController controller;

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
    final config = widget.controller.bridgeConfig;

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
    final status = widget.controller.status;
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

  final FitnessController controller;

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
  FitnessController controller,
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
  final activeLog = controller.activeWorkoutLog;
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
    final timing = controller.timingForExercise(exercise.exerciseId);
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
    final refreshedLog = controller.activeWorkoutLog;
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
  FitnessController controller,
  ExercisePrescription exercise,
) async {
  final activeLog = controller.activeWorkoutLog;
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
  FitnessController controller, {
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
  FitnessController controller,
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
  FitnessController controller,
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
  FitnessController controller,
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
