import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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

  @override
  Widget build(BuildContext context) {
    final controller = FitnessScope.of(context);
    final l = AppLocalizations.of(context)!;
    // When a workout has just been auto-closed, jump back to the Today
    // tab so the user lands on the inline summary instead of whatever
    // tab they were on. Consume the flag so we only do it once.
    if (controller.justCompletedLog != null) {
      if (index != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => index = 0);
        });
      }
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.clearJustCompleted(),
      );
    }
    final pages = [
      _TodayPage(controller: controller),
      _BlocksPage(controller: controller),
      _NutritionPage(controller: controller),
      _CoachPage(controller: controller),
      _ProgressPage(controller: controller),
    ];
    final titles = [
      l.navHeute,
      l.navBlocks,
      l.nutritionHeaderTitle,
      l.navCoach,
      l.navProgress,
    ];

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
                  _StatusBar(text: controller.status),
                  if (controller.hasPendingCodexBlock)
                    _CodexBlockAvailableBanner(controller: controller),
                  Expanded(child: pages[index]),
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
                icon: const Icon(CupertinoIcons.calendar),
                label: l.navBlocks,
              ),
              NavigationDestination(
                icon: const Icon(CupertinoIcons.chart_pie),
                label: l.navErnaehrung,
              ),
              NavigationDestination(
                icon: const Icon(CupertinoIcons.sparkles),
                label: l.navCoach,
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
        actions: [
          IconButton(
            tooltip: l.tooltipHealthKit,
            onPressed: controller.connectHealth,
            icon: const Icon(CupertinoIcons.heart),
          ),
          IconButton(
            tooltip: l.tooltipExport,
            onPressed: controller.exportDailySnapshot,
            icon: const Icon(CupertinoIcons.square_arrow_up),
          ),
        ],
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
      return _TodayEmptyState(controller: controller);
    }

    // If a workout has already been completed today, the Today tab
    // shows its inline summary instead of any training UI for the
    // remaining/next planned workout.
    final todayKey = dateKey(DateTime.now());
    final logsCompletedToday =
        data.logs
            .where(
              (log) =>
                  log.completedAt != null &&
                  dateKey(log.completedAt!) == todayKey,
            )
            .toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    if (logsCompletedToday.isNotEmpty) {
      return ColoredBox(
        color: AppColors.bg,
        child: WorkoutSummaryView(logId: logsCompletedToday.first.id),
      );
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
          color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
        ),
      ),
    );
  }
}

class _RpeLegend extends StatelessWidget {
  const _RpeLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [
          _RpeLegendDot(label: 'Warm-up', color: AppColors.sage),
          SizedBox(width: 14),
          _RpeLegendDot(label: 'Moderat', color: AppColors.gold),
          SizedBox(width: 14),
          _RpeLegendDot(label: 'Hart', color: AppColors.coral),
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
            color: AppColors.ink.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _ExerciseListCard extends StatelessWidget {
  const _ExerciseListCard({
    required this.exercises,
    required this.controller,
    required this.hasActiveWorkout,
    required this.focusedExerciseId,
  });

  final List<ExercisePrescription> exercises;
  final dynamic controller;
  final bool hasActiveWorkout;
  final String? focusedExerciseId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            for (var i = 0; i < exercises.length; i++)
              _ExerciseRow(
                number: i + 1,
                exercise: exercises[i],
                isLast: i == exercises.length - 1,
                hasActiveWorkout: hasActiveWorkout,
                isFocused: focusedExerciseId == exercises[i].exerciseId,
                isRunning:
                    controller.isExerciseRunning(exercises[i].exerciseId)
                        as bool,
                isPaused:
                    controller.isExercisePaused(exercises[i].exerciseId)
                        as bool,
                isStopped:
                    controller.isExerciseStopped(exercises[i].exerciseId)
                        as bool,
                elapsed:
                    controller.elapsedForExercise(exercises[i].exerciseId)
                        as Duration?,
                onStart: () => controller.startExerciseTimer(
                  exerciseId: exercises[i].exerciseId,
                  exerciseName: exercises[i].name,
                ),
                onPause: () =>
                    controller.pauseExerciseTimer(exercises[i].exerciseId),
                onResume: () =>
                    controller.resumeExerciseTimer(exercises[i].exerciseId),
                onStop: () =>
                    _handleExerciseStop(context, controller, exercises[i]),
                onTap: () => _showSetDialog(context, controller, exercises[i]),
              ),
          ],
        ),
      ),
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
                const Text(
                  'CONDITIONING',
                  style: TextStyle(
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
                    color: AppColors.ink.withValues(alpha: 0.52),
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

class _SagePill extends StatelessWidget {
  const _SagePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.33)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
          color: AppColors.sage,
        ),
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
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.ink.withValues(alpha: AppOpacity.subtle),
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
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final pre =
        '${exercise.sets} × ${exercise.reps}'
        '${exercise.targetLoad.trim().isEmpty ? '' : ' · ${exercise.targetLoad}'}';
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
                  : AppColors.ink.withValues(alpha: 0.07),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: isFocused ? AppColors.sage : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pre,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.ink.withValues(alpha: 0.43),
                    ),
                  ),
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

Color _rpeColor(double rpe) {
  if (rpe <= 4) return AppColors.sage;
  if (rpe <= 6) return AppColors.gold;
  return AppColors.coral;
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
        color: AppColors.ink.withValues(alpha: 0.17),
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
          iconColor: isPaused ? AppColors.sage : AppColors.ink,
          background: AppColors.ink.withValues(alpha: 0.07),
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
              color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
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
    return ColoredBox(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
        children: [
          _TodayDateLine(text: _TodayPage._formatToday(context)),
          const SizedBox(height: AppSpacing.medium),
          EmptyHeroCard(
            isConnected: isConnected,
            onLoadPlan: controller.importCodexBlockPlan,
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
              'Dein Plan erscheint hier',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.4,
                color: AppColors.ink.withValues(alpha: 0.28),
              ),
            ),
          ),
        ],
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

class _BlocksPage extends StatelessWidget {
  const _BlocksPage({required this.controller});

  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data as FitnessData;
    final l = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroPanel(
          title: l.blocksHeroTitle,
          subtitle: l.blocksHeroSubtitle,
          body: l.blocksHeroBody,
          trailing: l.blocksCount(data.blocks.length),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: controller.importCodexBlockPlan,
          icon: const Icon(CupertinoIcons.arrow_down_doc),
          label: Text(l.btnImportTrainingJson),
        ),
        const SizedBox(height: 16),
        for (final block in data.blocks) _BlockCard(block: block),
      ],
    );
  }
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
            const SizedBox(height: 10),
            _YesterdayCard(
              log: latest,
              signal: guidance.signal,
              yesterdayRead: guidance.yesterdayRead,
              target: target,
            ),
            if (guidance.mealIdeas.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SectionLabel(
                label: AppLocalizations.of(context)!.sectionMealIdeas,
              ),
              const SizedBox(height: 8),
              _MealIdeasRow(ideas: guidance.mealIdeas),
            ],
          ],
          const SizedBox(height: 14),
          _SectionLabel(
            label: AppLocalizations.of(context)!.sectionMealAnalysis,
          ),
          const SizedBox(height: 8),
          if (data.pendingMealResult != null)
            _MealResultCardV2(
              result: data.pendingMealResult!,
              onAccept: () => controller.acceptMealAnalysis(
                calories: data.pendingMealResult!.calories,
                protein: data.pendingMealResult!.protein,
                carbs: data.pendingMealResult!.carbs,
                fat: data.pendingMealResult!.fat,
                bodyWeightKg: data.pendingMealResult!.bodyWeightKg > 0
                    ? data.pendingMealResult!.bodyWeightKg
                    : profile.weightKg,
                notes: '',
              ),
              onDiscard: () => controller.discardMealAnalysis(),
              onReview: () => _showMealResultDialog(
                context,
                controller,
                data.pendingMealResult!,
              ),
            )
          else if (data.pendingMealRequest != null)
            _PendingMealRequestCard(request: data.pendingMealRequest!)
          else
            _MealAnalysisCta(
              onTap: () => _showMealAnalysisDialog(context, controller),
            ),
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
        color: AppColors.ink.withValues(alpha: 0.04),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.10)),
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
              color: AppColors.ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.ink.withValues(alpha: 0.40),
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
            color: AppColors.ink,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              right,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
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
        color: AppColors.ink,
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
                    color: AppColors.ink.withValues(alpha: 0.62),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
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
          bottom: BorderSide(color: AppColors.ink.withValues(alpha: 0.07)),
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
              color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
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
                color:
                    trailingColor ??
                    AppColors.ink.withValues(alpha: AppOpacity.mutedText),
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
                    color: AppColors.ink,
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
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mealRationale,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.ink.withValues(alpha: 0.62),
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
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
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
                color: AppColors.ink.withValues(alpha: 0.58),
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
              color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
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
              color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
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
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              idea.why,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.ink.withValues(alpha: 0.55),
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
                      color: AppColors.ink,
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
                            color: AppColors.ink.withValues(alpha: 0.72),
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
                            color: AppColors.ink.withValues(
                              alpha: AppOpacity.mutedText,
                            ),
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
                            color: AppColors.ink.withValues(
                              alpha: AppOpacity.mutedText,
                            ),
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
                            backgroundColor: AppColors.ink,
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
                            backgroundColor: AppColors.ink.withValues(
                              alpha: 0.07,
                            ),
                            foregroundColor: AppColors.ink.withValues(
                              alpha: AppOpacity.mutedText,
                            ),
                            side: BorderSide(
                              color: AppColors.ink.withValues(alpha: 0.13),
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
            : AppColors.ink.withValues(alpha: 0.07),
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
              color: accent ? AppColors.sage : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

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
          color: AppColors.ink.withValues(alpha: 0.20),
          strokeWidth: 1.5,
          dashLength: 4,
          gapLength: 3,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.05),
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
                  color: AppColors.white,
                  border: Border.all(
                    color: AppColors.ink.withValues(alpha: 0.13),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CupertinoIcons.plus,
                  size: 18,
                  color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
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
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.codexBewertetTrainingsauswirkung,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.ink.withValues(
                              alpha: AppOpacity.mutedText,
                            ),
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

class _CoachPage extends StatefulWidget {
  const _CoachPage({required this.controller});

  final dynamic controller;

  @override
  State<_CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<_CoachPage> {
  int _focusIdx = 0;
  final Set<int> _doneSet = <int>{};

  @override
  Widget build(BuildContext context) {
    final workout = widget.controller.nextWorkout as PlannedWorkout?;
    final block = widget.controller.activeBlock as TrainingBlock?;
    final data = widget.controller.data as FitnessData;
    if (workout == null || block == null || workout.exercises.isEmpty) {
      return _CoachEmptyState(controller: widget.controller);
    }
    final exercises = workout.exercises;
    final i = _focusIdx.clamp(0, exercises.length - 1);
    final ex = exercises[i];

    return ColoredBox(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
        children: [
          _CoachHeader(week: workout.week, day: workout.day),
          const SizedBox(height: 10),
          _ProgressSegments(
            count: exercises.length,
            focusIdx: i,
            doneSet: _doneSet,
          ),
          const SizedBox(height: 5),
          Text(
            workout.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          _FocusCard(
            exercise: ex,
            idx: i,
            total: exercises.length,
            focus: workout.focus,
            canPrev: i > 0,
            canNext: i < exercises.length - 1,
            onPrev: () => setState(() {
              if (_focusIdx > 0) _focusIdx -= 1;
            }),
            onNext: () => setState(() {
              if (_focusIdx < exercises.length - 1) {
                _doneSet.add(_focusIdx);
                _focusIdx += 1;
              }
            }),
          ),
          const SizedBox(height: 10),
          _SectionLabel(
            label: AppLocalizations.of(context)!.sectionAlleUebungen,
          ),
          const SizedBox(height: 4),
          for (var j = 0; j < exercises.length; j++)
            _CoachExerciseRow(
              exercise: exercises[j],
              isActive: j == i,
              isDone: _doneSet.contains(j),
              isLast: j == exercises.length - 1,
              onTap: () => setState(() => _focusIdx = j),
            ),
          const SizedBox(height: AppSpacing.page),
          _MemoryWikiSection(
            controller: widget.controller,
            memories: data.memories,
          ),
        ],
      ),
    );
  }
}

class _CoachEmptyState extends StatelessWidget {
  const _CoachEmptyState({required this.controller});

  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data as FitnessData;
    return ColoredBox(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              AppLocalizations.of(context)!.coachEmptyState,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          _MemoryWikiSection(controller: controller, memories: data.memories),
        ],
      ),
    );
  }
}

class _CoachHeader extends StatelessWidget {
  const _CoachHeader({required this.week, required this.day});

  final int week;
  final int day;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        const Expanded(child: SizedBox()),
        Text(
          l.coachPageTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              l.weekDay(week, day),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressSegments extends StatelessWidget {
  const _ProgressSegments({
    required this.count,
    required this.focusIdx,
    required this.doneSet,
  });

  final int count;
  final int focusIdx;
  final Set<int> doneSet;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              decoration: BoxDecoration(
                color: doneSet.contains(i)
                    ? AppColors.sage
                    : i == focusIdx
                    ? AppColors.ink
                    : AppColors.ink.withValues(alpha: AppOpacity.subtle),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({
    required this.exercise,
    required this.idx,
    required this.total,
    required this.focus,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
  });

  final ExercisePrescription exercise;
  final int idx;
  final int total;
  final String focus;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final media = exercise.media;
    final setup = media?.setup ?? '';
    final cues = media?.cues ?? const <String>[];
    final explainerUri = Uri.tryParse(media?.explainerUrl ?? '');
    final hasVideo =
        explainerUri != null &&
        (explainerUri.scheme == 'http' || explainerUri.scheme == 'https');
    final rest = exercise.restSeconds;
    final restLabel = rest <= 0
        ? null
        : rest >= 60
        ? '${rest ~/ 60} min'
        : '${rest}s';
    final rpe = exercise.targetRpe;
    final rpeText = rpe == rpe.roundToDouble()
        ? rpe.toStringAsFixed(0)
        : rpe.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l.uebungProgress(idx + 1, total),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
                ),
              ),
              const Spacer(),
              if (focus.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: _SagePill(label: focus),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exercise.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.0,
              letterSpacing: -0.3,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(label: l.statSaetze, value: '${exercise.sets}'),
              const SizedBox(width: 5),
              _StatChip(label: l.statWdhl, value: exercise.reps),
              const SizedBox(width: 5),
              _StatChip(
                label: l.statLast,
                value: exercise.targetLoad.isEmpty ? '—' : exercise.targetLoad,
              ),
              const SizedBox(width: 5),
              _StatChip(label: l.statRpe, value: rpeText, accent: true),
              if (restLabel != null) ...[
                const SizedBox(width: 5),
                _StatChip(label: l.statPause, value: restLabel),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: AppColors.ink.withValues(alpha: AppOpacity.subtle),
          ),
          const SizedBox(height: 10),
          if (exercise.coachCue.trim().isNotEmpty) ...[
            Text(
              '"${exercise.coachCue}"',
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.45,
                color: AppColors.sage,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (setup.isNotEmpty) ...[
            Text(
              setup,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (cues.isNotEmpty) ...[
            for (final cue in cues)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '—',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.sage,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cue,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (hasVideo)
                _VideoPill(
                  onTap: () => launchUrl(
                    _preferYoutubeShorts(explainerUri),
                    mode: LaunchMode.externalApplication,
                  ),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              _RoundNavButton(
                enabled: canPrev,
                primary: false,
                icon: CupertinoIcons.arrow_left,
                onTap: onPrev,
              ),
              const SizedBox(width: 6),
              _RoundNavButton(
                enabled: canNext,
                primary: true,
                icon: CupertinoIcons.arrow_right,
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: accent
              ? AppColors.sage.withValues(alpha: 0.08)
              : AppColors.ink.withValues(alpha: AppOpacity.subtle),
          borderRadius: BorderRadius.circular(8),
          border: accent
              ? Border.all(color: AppColors.sage.withValues(alpha: 0.2))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.0,
                color: accent ? AppColors.sage : AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              ),
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

class _RoundNavButton extends StatelessWidget {
  const _RoundNavButton({
    required this.enabled,
    required this.primary,
    required this.icon,
    required this.onTap,
  });

  final bool enabled;
  final bool primary;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? (enabled
              ? AppColors.ink
              : AppColors.ink.withValues(alpha: AppOpacity.subtle))
        : (enabled
              ? AppColors.ink.withValues(alpha: AppOpacity.subtle)
              : AppColors.transparent);
    final fg = primary
        ? (enabled ? AppColors.paper : AppColors.ink.withValues(alpha: 0.22))
        : (enabled ? AppColors.ink : AppColors.ink.withValues(alpha: 0.22));
    final border = primary
        ? null
        : Border.all(
            color: AppColors.ink.withValues(
              alpha: enabled ? AppOpacity.borderTint : AppOpacity.subtle,
            ),
          );
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: border,
          ),
          child: Icon(icon, size: 16, color: fg),
        ),
      ),
    );
  }
}

class _CoachExerciseRow extends StatelessWidget {
  const _CoachExerciseRow({
    required this.exercise,
    required this.isActive,
    required this.isDone,
    required this.isLast,
    required this.onTap,
  });

  final ExercisePrescription exercise;
  final bool isActive;
  final bool isDone;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pre = exercise.sets == 1
        ? exercise.reps
        : '${exercise.sets} × ${exercise.reps}';
    final color = isDone
        ? AppColors.ink.withValues(alpha: AppOpacity.mutedText)
        : isActive
        ? AppColors.ink
        : AppColors.ink.withValues(alpha: AppOpacity.mutedIcon);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isLast
                  ? AppColors.transparent
                  : AppColors.ink.withValues(alpha: AppOpacity.subtle),
            ),
          ),
        ),
        child: Row(
          children: [
            _StatusDot(isActive: isActive, isDone: isDone),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                exercise.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Text(
              pre,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isActive, required this.isDone});

  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    if (isDone) {
      return Container(
        width: 19,
        height: 19,
        decoration: const BoxDecoration(
          color: AppColors.sage,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.check_mark,
          size: 11,
          color: AppColors.white,
        ),
      );
    }
    if (isActive) {
      return Container(
        width: 19,
        height: 19,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.paper,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 19,
      height: 19,
      child: CustomPaint(
        painter: _DashedCirclePainter(
          color: AppColors.ink.withValues(alpha: 0.22),
          strokeWidth: 1.5,
          dashLength: 3,
          gapLength: 2,
        ),
      ),
    );
  }
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

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
  });

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
    final rect = Offset.zero & size;
    final path = Path()..addOval(rect.deflate(strokeWidth / 2));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final n = d + dashLength > metric.length
            ? metric.length
            : d + dashLength;
        canvas.drawPath(metric.extractPath(d, n), paint);
        d = n + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}

class _MemoryWikiSection extends StatelessWidget {
  const _MemoryWikiSection({required this.controller, required this.memories});

  final dynamic controller;
  final List<MemoryEntry> memories;

  @override
  Widget build(BuildContext context) {
    final activeCount = memories.where((item) => item.active).length;
    final grouped = <MemoryCategory, List<MemoryEntry>>{};
    for (final memory in memories) {
      grouped.putIfAbsent(memory.category, () => []).add(memory);
    }
    final l = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.book),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.memoryWikiTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(l.memoryWikiAktiv(activeCount)),
                IconButton(
                  tooltip: l.tooltipMemoryHinzufuegen,
                  onPressed: () => _showMemoryDialog(context, controller),
                  icon: const Icon(CupertinoIcons.add_circled),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.memoryWikiSubtitle,
              style: TextStyle(
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              ),
            ),
            const SizedBox(height: 12),
            if (memories.isEmpty)
              Text(
                l.memoryWikiEmpty,
                style: TextStyle(
                  color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
                ),
              )
            else
              for (final category in MemoryCategory.values)
                if ((grouped[category] ?? const <MemoryEntry>[]).isNotEmpty)
                  _MemoryCategoryGroup(
                    category: category,
                    memories: grouped[category]!,
                    controller: controller,
                  ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCategoryGroup extends StatelessWidget {
  const _MemoryCategoryGroup({
    required this.category,
    required this.memories,
    required this.controller,
  });

  final MemoryCategory category;
  final List<MemoryEntry> memories;
  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: category == MemoryCategory.goal,
      title: Text(
        '${category.label} (${memories.length})',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      children: [
        for (final memory in memories)
          _MemoryCard(
            memory: memory,
            onToggle: (value) => controller.toggleMemory(memory.id, value),
            onEdit: () =>
                _showMemoryDialog(context, controller, existing: memory),
            onDelete: () => controller.deleteMemory(memory.id),
          ),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.memory,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final MemoryEntry memory;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(
          color: AppColors.ink.withValues(alpha: AppOpacity.subtle),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  memory.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Switch(value: memory.active, onChanged: onToggle),
            ],
          ),
          Text(memory.summary),
          if (memory.markdown.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              memory.markdown,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${memory.source} · ${(memory.confidence * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.ink.withValues(
                      alpha: AppOpacity.mutedText,
                    ),
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return IconButton(
                    tooltip: l.tooltipBearbeiten,
                    onPressed: onEdit,
                    icon: const Icon(CupertinoIcons.pencil, size: 18),
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final l = AppLocalizations.of(context)!;
                  return IconButton(
                    tooltip: l.tooltipLoeschen,
                    onPressed: onDelete,
                    icon: const Icon(CupertinoIcons.trash, size: 18),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

class _ProgressPage extends StatelessWidget {
  const _ProgressPage({required this.controller});

  final dynamic controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data as FitnessData;
    final completed = data.logs.where((log) => log.completedAt != null).length;
    final totalVolume = data.logs.fold<double>(
      0,
      (sum, log) => sum + log.totalVolume,
    );
    final l = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroPanel(
          title: l.progressHeroTitle,
          subtitle: data.activeBlock?.title ?? 'No active block',
          body: l.progressHeroBody,
          trailing: l.progressDone(completed),
        ),
        const SizedBox(height: 12),
        _MetricGrid(
          metrics: [
            ('Workouts', '$completed'),
            ('Volume', '${totalVolume.toStringAsFixed(0)} kg'),
            ('Blocks', '${data.blocks.length}'),
            ('Logs', '${data.logs.length}'),
          ],
        ),
        const SizedBox(height: 16),
        for (final log in data.logs.take(12))
          ListTile(
            leading: const Icon(CupertinoIcons.flame),
            title: Text(log.title),
            subtitle: Text(
              l.progressLogSets(
                log.sets.length,
                log.totalVolume.toStringAsFixed(0),
                log.healthWriteStatus,
              ),
            ),
            trailing: IconButton(
              tooltip: 'Delete log',
              icon: Icon(
                Icons.delete_outline,
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedIcon),
              ),
              onPressed: () => _confirmDeleteLog(context, controller, log),
            ),
            onLongPress: () => _confirmDeleteLog(context, controller, log),
          ),
      ],
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
  late Future<String> _exchangePath;
  late final TextEditingController _bridgeUrlController;
  late final TextEditingController _bridgeTokenController;
  bool _bridgeBusy = false;

  @override
  void initState() {
    super.initState();
    _exchangePath = widget.controller.exchangeDirectoryPath();
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
    return FutureBuilder<String>(
      future: _exchangePath,
      builder: (context, snapshot) {
        final l = AppLocalizations.of(context)!;
        final exchangePath = snapshot.data ?? l.exchangeFolderLoading;
        final handoff = _agentHandoffPayload(exchangePath);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeroPanel(
              title: l.settingsHeroTitle,
              subtitle: l.settingsHeroSubtitle,
              body: l.settingsHeroBody,
              trailing: snapshot.hasData
                  ? l.settingsHeroReady
                  : l.settingsHeroLoading,
            ),
            const SizedBox(height: 12),
            _LocalBridgeCard(
              controller: widget.controller,
              urlController: _bridgeUrlController,
              tokenController: _bridgeTokenController,
              busy: _bridgeBusy,
              onAction: _runBridgeAction,
            ),
            const SizedBox(height: 12),
            _AgentHandoffCard(handoff: handoff, enabled: snapshot.hasData),
            const SizedBox(height: 12),
            _SetupChecklistCard(exchangePath: exchangePath),
          ],
        );
      },
    );
  }

  Future<void> _runBridgeAction(Future<void> Function() action) async {
    if (_bridgeBusy) return;
    setState(() => _bridgeBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _bridgeBusy = false);
    }
  }
}

class _LocalBridgeCard extends StatelessWidget {
  const _LocalBridgeCard({
    required this.controller,
    required this.urlController,
    required this.tokenController,
    required this.busy,
    required this.onAction,
  });

  final dynamic controller;
  final TextEditingController urlController;
  final TextEditingController tokenController;
  final bool busy;
  final Future<void> Function(Future<void> Function() action) onAction;

  @override
  Widget build(BuildContext context) {
    final config = controller.bridgeConfig;
    final lastSync = config.lastSyncAt == null
        ? 'No server sync yet'
        : 'Last server sync: ${DateFormat.yMd().add_Hm().format(config.lastSyncAt!)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.dot_radiowaves_left_right),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Self-Hosted T4L Server',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  config.isConfigured ? 'Configured' : 'Optional',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to your own T4L server. The phone stays the source of '
              'truth, and new plans still need your import confirmation.',
              style: TextStyle(
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.1.42:8787',
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'API key',
                hintText: 'Paste the key printed by t4l-server',
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => onAction(() async {
                          await controller.saveBridgeConfig(
                            baseUrl: urlController.text,
                            token: tokenController.text,
                          );
                          await controller.testBridgeConnection();
                        }),
                  icon: const Icon(CupertinoIcons.link),
                  label: const Text('Connect'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => onAction(controller.migrateToServer),
                  icon: const Icon(CupertinoIcons.tray_arrow_up),
                  label: const Text('Migrate Data'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => onAction(controller.pushBridgeContext),
                  icon: const Icon(CupertinoIcons.arrow_up_doc),
                  label: const Text('Push Context'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => onAction(controller.pullBridgeResults),
                  icon: const Icon(CupertinoIcons.arrow_down_doc),
                  label: const Text('Check Results'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (busy) const LinearProgressIndicator(),
            if (busy) const SizedBox(height: 8),
            Text(
              '$lastSync\n${controller.status}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentHandoffCard extends StatelessWidget {
  const _AgentHandoffCard({required this.handoff, required this.enabled});

  final String handoff;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final copyTooltip = AppLocalizations.of(context)!.tooltipKopieren;
    return Card(
      child: ExpansionTile(
        leading: const Icon(CupertinoIcons.square_arrow_up),
        title: const Text(
          'Complete Agent Handoff',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Copy this once and send it to Codex or Claude.'),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Share via AirDrop',
              onPressed: enabled ? () => _shareHandoff(context, handoff) : null,
              icon: const Icon(CupertinoIcons.share),
            ),
            IconButton(
              tooltip: copyTooltip,
              onPressed: enabled
                  ? () => _copyToClipboard(context, handoff)
                  : null,
              icon: const Icon(CupertinoIcons.doc_on_doc),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SelectableText(
            handoff,
            style: TextStyle(
              color: AppColors.ink.withValues(alpha: AppOpacity.inverseBody),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupChecklistCard extends StatelessWidget {
  const _SetupChecklistCard({required this.exchangePath});

  final String exchangePath;

  @override
  Widget build(BuildContext context) {
    final items = [
      'Read the local agent instructions repo first.',
      'Install or verify t4l-server, then start the self-hosted server.',
      'If long-term goal or current block target is unclear, start with goal discovery before coaching.',
      'Push fresh context from the app before coaching.',
      'Inspect day_context.json, daily_snapshot.json, athlete_profile.json, active block, next workout, logs, nutrition, HealthKit activity, and memoryWiki.',
      'Separate facts from assumptions. Missing HealthKit data is unknown, not zero.',
      'Choose today: progress, hold, substitute, deload, or rest.',
      'Give food-based nutrition guidance from today\'s training and yesterday\'s intake pattern.',
      'Verify any app JSON before writing it through MCP tools.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.check_mark_circled),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.settingsChecklist,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        CupertinoIcons.smallcircle_fill_circle,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.block});

  final TrainingBlock block;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          block.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          AppLocalizations.of(
            context,
          )!.blockCardWeeks(block.durationWeeks, block.createdBy),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(block.weeklyFocus.join('\n')),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(
                context,
              )!.blockCardTargets(block.measurableTargets.join(', ')),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(
                context,
              )!.blockCardWorkouts(block.workouts.length),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final String body;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.hero),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.white.withValues(
                      alpha: AppOpacity.inverseMuted,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                trailing,
                style: TextStyle(
                  color: scheme.secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            body,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: AppOpacity.inverseBody),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<(String, String)> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 80,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            metric.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
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
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _agentHandoffPayload(String exchangePath) {
  return '''
You are my T4L Trainer coaching agent.

Agent instructions repo:
$_agentInstructionsRepo

Server install command:
$_bridgeInstallCommand

Server start command:
$_bridgeServeCommand

Informational iPhone exchange path:
$exchangePath

Please read the agent instructions repo and follow the adapter for your runtime.
'''
      .trim();
}

Future<void> _copyToClipboard(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  final l = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l.snackbarKopiert)));
}

Future<void> _shareHandoff(BuildContext context, String value) async {
  try {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: value,
        subject: 'T4L Trainer Agent Handoff',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } on MissingPluginException {
    if (!context.mounted) return;
    await _copyToClipboard(context, value);
  }
}

class _CodexBlockAvailableBanner extends StatelessWidget {
  const _CodexBlockAvailableBanner({required this.controller});

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
              AppLocalizations.of(context)!.neuerCodexBlock,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton.icon(
            onPressed: controller.importCodexBlockPlan,
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
      history: history,
    );
    if (result == null || result.delete) break;
    await controller.logSet(exercise, result.weightKg, result.reps, result.rpe);
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

Future<void> _confirmDeleteLog(
  BuildContext context,
  dynamic controller,
  WorkoutLog log,
) async {
  final dateText = DateFormat('d. MMM yyyy, HH:mm').format(log.startedAt);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete this log?'),
      content: Text(
        '${log.title}\n$dateText\n\n'
        '${log.sets.length} sets · ${log.totalVolume.toStringAsFixed(0)} kg\n'
        'Status: ${log.healthWriteStatus}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.coral),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.removeWorkoutLog(log.id);
  }
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
    history: history,
  );
  if (result == null || result.delete) return;
  await controller.logSet(exercise, result.weightKg, result.reps, result.rpe);
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
                  title: Text(l.dialogMemoryAktivFuerCodex),
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
              child: Text(l.btnAnCodexSenden),
            ),
          ],
        );
      },
    ),
  );
}

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
