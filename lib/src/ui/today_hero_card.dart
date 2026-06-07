import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/fitness_models.dart';

enum HeroWorkoutStatus { bereit, aktiv, pause, fertig }

class TodayHeroCard extends StatelessWidget {
  const TodayHeroCard({
    super.key,
    required this.status,
    required this.block,
    required this.workout,
    required this.dayIndex,
    required this.totalDays,
    required this.sessionMinutes,
    required this.totalSets,
    required this.completedSets,
    required this.blockProgressPercent,
    required this.sessionElapsed,
    required this.avgRpe,
    required this.focusedExercise,
    required this.focusedStepContext,
    required this.focusedExerciseIndex,
    required this.focusedExerciseElapsed,
    required this.focusedExerciseIsPaused,
    required this.canDismissFocus,
    required this.totalExercises,
    required this.onStart,
    required this.onComplete,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onExercisePause,
    required this.onExerciseResume,
    required this.onExerciseStop,
    required this.onDismissExerciseFocus,
    this.dailyMotto,
  });

  final HeroWorkoutStatus status;
  final TrainingBlock block;
  final PlannedWorkout workout;
  final int dayIndex;
  final int totalDays;
  final int sessionMinutes;
  final int totalSets;
  final int completedSets;
  final int blockProgressPercent;
  final Duration? sessionElapsed;
  final double? avgRpe;

  final ExercisePrescription? focusedExercise;
  final String? focusedStepContext;
  final int focusedExerciseIndex;
  final Duration? focusedExerciseElapsed;
  final bool focusedExerciseIsPaused;
  final bool canDismissFocus;
  final int totalExercises;

  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onExercisePause;
  final VoidCallback onExerciseResume;
  final VoidCallback onExerciseStop;
  final VoidCallback onDismissExerciseFocus;
  final String? dailyMotto;

  static const _gradientTop = Color(0xFF1D2A1F);
  static const _gradientMid = Color(0xFF18201B);
  static const _gradientBot = Color(0xFF121B14);

  @override
  Widget build(BuildContext context) {
    final isActive =
        status == HeroWorkoutStatus.aktiv || status == HeroWorkoutStatus.pause;
    final showExercise = focusedExercise != null && isActive;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.55, -1),
          end: Alignment(0.55, 1),
          colors: [_gradientTop, _gradientMid, _gradientBot],
          stops: [0.0, 0.52, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.paper.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.30),
            blurRadius: 60,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Top-edge shimmer.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.paper.withValues(alpha: 0),
                      AppColors.paper.withValues(alpha: 0.22),
                      AppColors.paper.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: showExercise
                    ? _HeroExercise(
                        key: const ValueKey('hero-exercise'),
                        exercise: focusedExercise!,
                        stepContext: focusedStepContext,
                        exerciseIndex: focusedExerciseIndex,
                        totalExercises: totalExercises,
                        elapsed: focusedExerciseElapsed,
                        isPaused: focusedExerciseIsPaused,
                        canDismiss: canDismissFocus,
                        onPause: onExercisePause,
                        onResume: onExerciseResume,
                        onStop: onExerciseStop,
                        onDismiss: onDismissExerciseFocus,
                      )
                    : _HeroOverview(
                        key: const ValueKey('hero-overview'),
                        status: status,
                        block: block,
                        workout: workout,
                        dayIndex: dayIndex,
                        totalDays: totalDays,
                        sessionMinutes: sessionMinutes,
                        totalSets: totalSets,
                        completedSets: completedSets,
                        blockProgressPercent: blockProgressPercent,
                        sessionElapsed: sessionElapsed,
                        avgRpe: avgRpe,
                        dailyMotto: dailyMotto,
                        onStart: onStart,
                        onComplete: onComplete,
                        onPause: onPause,
                        onResume: onResume,
                        onStop: onStop,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status pill ──────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final HeroWorkoutStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (color, bgAlpha, borderAlpha, live) = switch (status) {
      HeroWorkoutStatus.bereit => (AppColors.gold, 0.12, 0.30, false),
      HeroWorkoutStatus.aktiv => (AppColors.coral, 0.12, 0.30, true),
      HeroWorkoutStatus.pause => (AppColors.gold, 0.12, 0.30, false),
      HeroWorkoutStatus.fertig => (AppColors.sage, 0.14, 0.30, false),
    };
    final label = switch (status) {
      HeroWorkoutStatus.bereit => l.statusBereit,
      HeroWorkoutStatus.aktiv => l.statusAktiv,
      HeroWorkoutStatus.pause => l.statusPause,
      HeroWorkoutStatus.fertig => l.statusFertig,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: borderAlpha)),
      ),
      child: _LivePulse(
        enabled: live,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _LivePulse extends StatefulWidget {
  const _LivePulse({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _LivePulse old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) =>
          Opacity(opacity: 0.35 + 0.65 * (1 - _c.value), child: child),
      child: widget.child,
    );
  }
}

// ─── Hero overview mode ───────────────────────────────────────────

class _HeroOverview extends StatelessWidget {
  const _HeroOverview({
    super.key,
    required this.status,
    required this.block,
    required this.workout,
    required this.dayIndex,
    required this.totalDays,
    required this.sessionMinutes,
    required this.totalSets,
    required this.completedSets,
    required this.blockProgressPercent,
    required this.sessionElapsed,
    required this.avgRpe,
    this.dailyMotto,
    required this.onStart,
    required this.onComplete,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final HeroWorkoutStatus status;
  final TrainingBlock block;
  final PlannedWorkout workout;
  final int dayIndex;
  final int totalDays;
  final int sessionMinutes;
  final int totalSets;
  final int completedSets;
  final int blockProgressPercent;
  final Duration? sessionElapsed;
  final double? avgRpe;
  final String? dailyMotto;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final running =
        status == HeroWorkoutStatus.aktiv || status == HeroWorkoutStatus.pause;
    final done = status == HeroWorkoutStatus.fertig;
    const paper = AppColors.paper;
    final stats = running
        ? [
            (l.statAktivLabel, _fmtElapsed(sessionElapsed ?? Duration.zero)),
            (l.heroSaetze, '$completedSets / $totalSets'),
            (
              l.statRpeAvg,
              avgRpe == null
                  ? '—'
                  : '~${avgRpe!.toStringAsFixed(avgRpe! >= 10 ? 0 : 1)}',
            ),
          ]
        : [
            (l.statPlanzeit, '$sessionMinutes min'),
            (l.heroSaetze, '$totalSets'),
            (l.statTagLabel, '$dayIndex / $totalDays'),
          ];

    final eyebrowText = [
      block.style.label,
      l.heroTag(dayIndex),
      l.woche(workout.week),
    ].join(' · ').toUpperCase();

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _StatusPill(status: status),
            const Spacer(),
            Text(
              running
                  ? _fmtElapsed(sessionElapsed ?? Duration.zero)
                  : '$blockProgressPercent% Block',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: running
                    ? AppColors.coral
                    : paper.withValues(alpha: 0.26),
                letterSpacing: running ? 0.9 : 0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          eyebrowText,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: paper.withValues(alpha: 0.30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          workout.title.toUpperCase(),
          style: const TextStyle(
            fontSize: 34,
            height: 0.95,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: paper,
          ),
        ),
        if (workout.focus.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            workout.focus,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: paper.withValues(alpha: 0.36),
              letterSpacing: 0.2,
            ),
          ),
        ],
        if (dailyMotto != null && dailyMotto!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.sage.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
            ),
            child: Text(
              '"${dailyMotto!.trim()}"',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.sage.withValues(alpha: 0.72),
                height: 1.4,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: (blockProgressPercent / 100).clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: paper.withValues(alpha: 0.10),
            valueColor: const AlwaysStoppedAnimation(AppColors.sage),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              Expanded(
                child: _StatTile(label: stats[i].$1, value: stats[i].$2),
              ),
              if (i < stats.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 18),
        if (done)
          Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.sage.withValues(alpha: 0.22)),
            ),
            child: Text(
              l.statusAbgeschlossen,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: AppColors.sage,
              ),
            ),
          )
        else if (running)
          _OverviewActiveControls(
            isPaused: status == HeroWorkoutStatus.pause,
            onPause: onPause,
            onResume: onResume,
            onStop: onStop,
          )
        else
          _OverviewReadyControls(onStart: onStart, onComplete: onComplete),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const paper = AppColors.paper;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: paper.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: paper.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: paper.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: paper,
              letterSpacing: -0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}

class _OverviewStartButton extends StatelessWidget {
  const _OverviewStartButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, size: 18),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.btnTrainingStarten,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewReadyControls extends StatelessWidget {
  const _OverviewReadyControls({
    required this.onStart,
    required this.onComplete,
  });

  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    const paper = AppColors.paper;
    return Column(
      children: [
        _OverviewStartButton(onTap: onStart),
        const SizedBox(height: 9),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: onComplete,
            style: OutlinedButton.styleFrom(
              foregroundColor: paper.withValues(alpha: 0.72),
              side: BorderSide(color: paper.withValues(alpha: 0.18)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              AppLocalizations.of(context)!.btnWorkoutAbschliessen,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewActiveControls extends StatelessWidget {
  const _OverviewActiveControls({
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const paper = AppColors.paper;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: isPaused ? onResume : onPause,
              style: FilledButton.styleFrom(
                backgroundColor: isPaused
                    ? AppColors.sage
                    : paper.withValues(alpha: 0.07),
                foregroundColor: isPaused
                    ? AppColors.white
                    : paper.withValues(alpha: 0.62),
                side: isPaused
                    ? BorderSide.none
                    : BorderSide(color: paper.withValues(alpha: 0.13)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                isPaused ? l.btnWeiter : l.btnPauseLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: onStop,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral.withValues(alpha: 0.13),
                foregroundColor: AppColors.coral,
                side: BorderSide(
                  color: AppColors.coral.withValues(alpha: 0.28),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text(
                l.btnFertig,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Hero exercise-focus mode ─────────────────────────────────────

class _HeroExercise extends StatelessWidget {
  const _HeroExercise({
    super.key,
    required this.exercise,
    required this.stepContext,
    required this.exerciseIndex,
    required this.totalExercises,
    required this.elapsed,
    required this.isPaused,
    required this.canDismiss,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onDismiss,
  });

  final ExercisePrescription exercise;
  final String? stepContext;
  final int exerciseIndex;
  final int totalExercises;
  final Duration? elapsed;
  final bool isPaused;
  final bool canDismiss;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const paper = AppColors.paper;
    final pre =
        '${exercise.sets} × ${exercise.reps}'
        '${exercise.displayLoadLabel.isEmpty ? '' : ' · ${exercise.displayLoadLabel}'}';
    final rpeColor = _rpeColor(exercise.targetRpe);
    final words = exercise.name.split(' ').where((w) => w.isNotEmpty);

    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _StatusPill(
              status: isPaused
                  ? HeroWorkoutStatus.pause
                  : HeroWorkoutStatus.aktiv,
            ),
            const Spacer(),
            Text(
              _fmtElapsed(elapsed ?? Duration.zero),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isPaused ? AppColors.gold : AppColors.coral,
                letterSpacing: 0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              l.uebungProgress(exerciseIndex, totalExercises),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7,
                color: paper.withValues(alpha: 0.30),
              ),
            ),
            const Spacer(),
            if (canDismiss && isPaused)
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  l.heroUebersicht,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: paper.withValues(alpha: 0.38),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (stepContext?.trim().isNotEmpty ?? false) ...[
          Text(
            stepContext!.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: AppColors.sage.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 8),
        ],
        for (final word in words)
          Text(
            word.toUpperCase(),
            style: const TextStyle(
              fontSize: 30,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: paper,
            ),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              pre,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: paper.withValues(alpha: 0.70),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '·',
                  style: TextStyle(
                    fontSize: 14,
                    color: paper.withValues(alpha: 0.20),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: rpeColor.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'RPE ${exercise.targetRpe.toStringAsFixed(exercise.targetRpe % 1 == 0 ? 0 : 1)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: paper.withValues(alpha: 0.42),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (exercise.displayPrimaryCue.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: paper.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: paper.withValues(alpha: 0.09)),
            ),
            child: Text(
              '"${exercise.displayPrimaryCue}"',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: paper.withValues(alpha: 0.55),
                height: 1.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _OverviewActiveControls(
          isPaused: isPaused,
          onPause: onPause,
          onResume: onResume,
          onStop: onStop,
        ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────

String _fmtElapsed(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
}

Color _rpeColor(double rpe) {
  if (rpe <= 4) return AppColors.sage;
  if (rpe <= 6) return AppColors.gold;
  return AppColors.coral;
}

// ─── Empty hero card (no active block) ───────────────────────────

class EmptyHeroCard extends StatelessWidget {
  const EmptyHeroCard({
    super.key,
    required this.isConnected,
    required this.onLoadPlan,
    required this.onConnect,
  });

  final bool isConnected;
  final VoidCallback onLoadPlan;
  final VoidCallback onConnect;

  static const _gradientTop = Color(0xFF1D2A1F);
  static const _gradientMid = Color(0xFF18201B);
  static const _gradientBot = Color(0xFF121B14);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const paper = AppColors.paper;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.55, -1),
          end: Alignment(0.55, 1),
          colors: [_gradientTop, _gradientMid, _gradientBot],
          stops: [0.0, 0.52, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: paper.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.30),
            blurRadius: 60,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      paper.withValues(alpha: 0),
                      paper.withValues(alpha: 0.22),
                      paper.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: paper.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: paper.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Text(
                          isConnected
                              ? l.emptyKeinBlock
                              : l.emptyNichtVerbunden,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: paper.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '0%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: paper.withValues(alpha: 0.18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    l.emptyDein,
                    style: const TextStyle(
                      fontSize: 40,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: paper,
                    ),
                  ),
                  Text(
                    l.emptyErster,
                    style: const TextStyle(
                      fontSize: 40,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: paper,
                    ),
                  ),
                  Text(
                    l.emptyTag,
                    style: const TextStyle(
                      fontSize: 40,
                      height: 0.9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: AppColors.sage,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 3,
                      color: paper.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _GhostStatTile(label: l.statPlanzeit)),
                      const SizedBox(width: 8),
                      Expanded(child: _GhostStatTile(label: l.heroSaetze)),
                      const SizedBox(width: 8),
                      Expanded(child: _GhostStatTile(label: l.statTagLabel)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  if (isConnected)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: onLoadPlan,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.sage,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.file_download_outlined, size: 16),
                            const SizedBox(width: 11),
                            Text(
                              l.btnTrainingsplanLaden,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: onConnect,
                        style: FilledButton.styleFrom(
                          backgroundColor: paper.withValues(alpha: 0.08),
                          foregroundColor: paper.withValues(alpha: 0.72),
                          side: BorderSide(
                            color: paper.withValues(alpha: 0.16),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          l.btnCoachVerbinden,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostStatTile extends StatelessWidget {
  const _GhostStatTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    const paper = AppColors.paper;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: paper.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: paper.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: paper.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '—',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: paper.withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
  }
}

class GhostExerciseSection extends StatelessWidget {
  const GhostExerciseSection({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [0.66, 0.50, 0.74, 0.42];
    return Opacity(
      opacity: 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i < rows.length - 1
                            ? AppColors.paper.withValues(alpha: 0.06)
                            : AppColors.transparent,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.sage.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width:
                                  MediaQuery.of(context).size.width *
                                  rows[i] *
                                  0.55,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.paper.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: MediaQuery.of(context).size.width * 0.20,
                              height: 7,
                              decoration: BoxDecoration(
                                color: AppColors.paper.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(3),
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
        ),
      ),
    );
  }
}
