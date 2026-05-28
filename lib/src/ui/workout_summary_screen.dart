import 'package:flutter/material.dart';
import '../app.dart';
import '../design/design_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/fitness_models.dart';
import '../state/fitness_controller.dart';
import 'set_log_modal.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key, required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          l.workoutSummaryTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: WorkoutSummaryView(
          logId: logId,
          onDone: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class WorkoutSummaryView extends StatefulWidget {
  const WorkoutSummaryView({super.key, required this.logId, this.onDone});

  final String logId;
  final VoidCallback? onDone;

  @override
  State<WorkoutSummaryView> createState() => _WorkoutSummaryViewState();
}

class _WorkoutSummaryViewState extends State<WorkoutSummaryView> {
  late final TextEditingController _notes;
  int _readiness = 3;
  int _soreness = 2;
  bool _seeded = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController();
    _notes.addListener(_onNotesChanged);
  }

  void _onNotesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _notes.removeListener(_onNotesChanged);
    _notes.dispose();
    super.dispose();
  }

  WorkoutLog? _findLog(FitnessController controller) {
    for (final log in controller.data.logs) {
      if (log.id == widget.logId) return log;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final controller = FitnessScope.of(context);
    final log = _findLog(controller);
    if (log == null) {
      return Center(child: Text(l.workoutNotFound));
    }
    if (!_seeded) {
      _readiness = log.readiness;
      _soreness = log.soreness;
      _notes.text = log.notes;
      _seeded = true;
    }

    final totalSets = log.sets.length;
    final totalActive = log.totalDurationSeconds ?? 0;
    final allRpe = log.sets.map((s) => s.rpe).toList();
    final avgRpe = allRpe.isEmpty
        ? null
        : allRpe.reduce((a, b) => a + b) / allRpe.length;

    // Try to find the associated block for the banner
    final block = controller.activeBlock;
    final workout = block?.workouts.cast<PlannedWorkout?>().firstWhere(
      (w) => w!.id == log.workoutId,
      orElse: () => block.workouts.isNotEmpty ? block.workouts.first : null,
    );
    final completedInBlock = block == null
        ? 0
        : controller.data.logs
              .where(
                (l) =>
                    l.completedAt != null &&
                    block.workouts.any((w) => w.id == l.workoutId),
              )
              .length;
    final blockProgress = block == null || block.workouts.isEmpty
        ? 0
        : ((completedInBlock / block.workouts.length) * 100).round();

    return ColoredBox(
      color: AppColors.bg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          _PostWorkoutBanner(
            title: log.title,
            block: block,
            workout: workout,
            blockProgress: blockProgress,
            activeSeconds: totalActive,
            totalSets: totalSets,
            avgRpe: avgRpe,
          ),
          const SizedBox(height: 20),
          _SectionLabel(l.uebungenUeberpruefen),
          const SizedBox(height: 10),
          ...log.exerciseTimings.map((t) {
            final pairs = <_IndexedSet>[];
            for (var i = 0; i < log.sets.length; i++) {
              final s = log.sets[i];
              if (s.exerciseId == t.exerciseId) {
                pairs.add(_IndexedSet(s, i));
              }
            }
            pairs.sort((a, b) => a.set.setNumber.compareTo(b.set.setNumber));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExerciseReviewCard(
                logId: log.id,
                timing: t,
                indexedSets: pairs,
              ),
            );
          }),
          if (log.exerciseTimings.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l.keineUebungenAufgezeichnet,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.paper.withValues(alpha: 0.28),
                ),
              ),
            ),
          _ReflectionCard(
            readiness: _readiness,
            soreness: _soreness,
            notes: _notes,
            onReadiness: (v) => setState(() => _readiness = v),
            onSoreness: (v) => setState(() => _soreness = v),
          ),
          const SizedBox(height: 16),
          _SendButton(
            sent: _sent,
            onSend: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              await Future<void>.delayed(const Duration(milliseconds: 30));
              await controller.updateCompletedLog(
                widget.logId,
                notes: _notes.text.trim(),
                readiness: _readiness,
                soreness: _soreness,
              );
              if (!context.mounted) return;
              setState(() => _sent = true);
              widget.onDone?.call();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Post-workout banner (hero card style) ───────────────────────────

class _PostWorkoutBanner extends StatelessWidget {
  const _PostWorkoutBanner({
    required this.title,
    required this.block,
    required this.workout,
    required this.blockProgress,
    required this.activeSeconds,
    required this.totalSets,
    required this.avgRpe,
  });

  final String title;
  final TrainingBlock? block;
  final PlannedWorkout? workout;
  final int blockProgress;
  final int activeSeconds;
  final int totalSets;
  final double? avgRpe;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    const paper = AppColors.paper;
    final eyebrow = block != null && workout != null
        ? '${block!.style.label} · ${l.heroTag(workout!.day)} · ${l.woche(workout!.week)}'
              .toUpperCase()
        : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-0.55, -1),
          end: Alignment(0.55, 1),
          colors: [Color(0xFF1D2A1F), Color(0xFF18201B), Color(0xFF121B14)],
          stops: [0.0, 0.52, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: paper.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 60,
            offset: const Offset(0, 22),
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
                      paper.withValues(alpha: 0.20),
                      paper.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusPill(label: l.statusFertig, color: AppColors.sage),
                      const Spacer(),
                      Text(
                        '$blockProgress% Block',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: paper.withValues(alpha: 0.35),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (eyebrow.isNotEmpty)
                    Text(
                      eyebrow,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: paper.withValues(alpha: 0.30),
                      ),
                    ),
                  if (eyebrow.isNotEmpty) const SizedBox(height: 7),
                  Text(
                    (workout?.title ?? title).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 34,
                      height: 0.93,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: paper,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (blockProgress / 100).clamp(0.0, 1.0),
                      minHeight: 2,
                      backgroundColor: paper.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation(AppColors.sage),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _BannerStat(
                          label: l.dauerLabel.toUpperCase(),
                          value: _fmtDuration(activeSeconds),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BannerStat(
                          label: l.heroSaetze,
                          value: '$totalSets',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BannerStat(
                          label: l.statRpeAvg,
                          value: avgRpe?.toStringAsFixed(1) ?? '—',
                        ),
                      ),
                    ],
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          color: color,
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const paper = AppColors.paper;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: paper.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: paper.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: paper,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppColors.paper.withValues(alpha: 0.28),
      ),
    );
  }
}

// ── Exercise review card ────────────────────────────────────────────

class _IndexedSet {
  const _IndexedSet(this.set, this.index);
  final LoggedSet set;
  final int index;
}

class _ExerciseReviewCard extends StatefulWidget {
  const _ExerciseReviewCard({
    required this.logId,
    required this.timing,
    required this.indexedSets,
  });

  final String logId;
  final ExerciseTiming timing;
  final List<_IndexedSet> indexedSets;

  @override
  State<_ExerciseReviewCard> createState() => _ExerciseReviewCardState();
}

class _ExerciseReviewCardState extends State<_ExerciseReviewCard> {
  late final TextEditingController _notes;
  String _committedNotes = '';

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.timing.notes);
    _committedNotes = widget.timing.notes;
  }

  @override
  void didUpdateWidget(covariant _ExerciseReviewCard old) {
    super.didUpdateWidget(old);
    final remote = widget.timing.notes;
    if (remote != _committedNotes && _notes.text == _committedNotes) {
      _notes.text = remote;
      _committedNotes = remote;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _commitNotesIfChanged() async {
    final next = _notes.text.trim();
    if (next == _committedNotes) return;
    _committedNotes = next;
    await FitnessScope.of(
      context,
    ).updateExerciseNotes(widget.logId, widget.timing.exerciseId, next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final controller = FitnessScope.of(context);
    final dur = widget.timing.durationSeconds;
    final durText = dur == null ? '--' : _fmtDuration(dur);
    final border = AppColors.paper.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.timing.exerciseName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.paper,
                        ),
                      ),
                      if (widget.timing.healthSnapshot?.hasAnyValue ??
                          false) ...[
                        const SizedBox(height: 7),
                        _ExerciseHealthSummary(
                          metrics: widget.timing.healthSnapshot!,
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  durText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.paper.withValues(alpha: 0.48),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          // Set rows
          if (widget.indexedSets.isNotEmpty)
            Column(
              children: [
                for (final pair in widget.indexedSets)
                  _SetRow(
                    set: pair.set,
                    border: border,
                    onEdit: () => _openEditSetDialog(context, controller, pair),
                  ),
              ],
            ),

          // Add set
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: GestureDetector(
              onTap: () => controller.addLoggedSet(
                widget.logId,
                exerciseId: widget.timing.exerciseId,
                exerciseName: widget.timing.exerciseName,
              ),
              child: Row(
                children: [
                  const Text(
                    '+',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sage,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l.satzHinzufuegen,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sage,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Notes
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 13),
            child: Focus(
              onFocusChange: (has) {
                if (!has) _commitNotesIfChanged();
              },
              child: TextField(
                controller: _notes,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commitNotesIfChanged(),
                style: const TextStyle(fontSize: 13, color: AppColors.paper),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: l.notizFuerCoach,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.paper.withValues(alpha: 0.28),
                  ),
                ),
                cursorColor: AppColors.sage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditSetDialog(
    BuildContext context,
    FitnessController controller,
    _IndexedSet pair,
  ) async {
    final l = AppLocalizations.of(context)!;
    final sameExercise = widget.indexedSets.map((p) => p.set).toList();
    final result = await showSetLogModal(
      context,
      exerciseName: pair.set.exerciseName,
      currentSetNumber: pair.set.setNumber,
      totalSets: sameExercise.isEmpty
          ? pair.set.setNumber
          : sameExercise.length,
      initialWeightKg: pair.set.weightKg,
      initialReps: pair.set.reps,
      initialRpe: pair.set.rpe,
      history: sameExercise
          .where((s) => s.setNumber != pair.set.setNumber)
          .toList(),
      allowDelete: true,
      saveLabel: l.btnSpeichern,
    );
    if (result == null) return;
    if (result.delete) {
      await controller.removeLoggedSet(widget.logId, pair.index);
    } else {
      await controller.updateLoggedSet(
        widget.logId,
        pair.index,
        weightKg: result.weightKg,
        reps: result.reps,
        rpe: result.rpe,
      );
    }
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
          icon: Icons.favorite,
          text: '${_fmtNum(metrics.heartRateBpm!)} bpm',
          color: AppColors.coral,
        ),
      if (metrics.activeEnergyKcal != null)
        _HealthMetricChip(
          icon: Icons.local_fire_department,
          text: '${_fmtNum(metrics.activeEnergyKcal!)} kcal',
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
          text: '${_fmtNum(metrics.bloodOxygenPercent!)}%',
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

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.border,
    required this.onEdit,
  });

  final LoggedSet set;
  final Color border;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final rpeColor = _rpeColorForValue(set.rpe);
    final isTime = set.isTimeBased;
    final weightText = set.weightKg == 0
        ? ''
        : ' · ${_fmtNum(set.weightKg)} kg';
    return GestureDetector(
      onTap: onEdit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                'S${set.setNumber}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sage,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isTime
                  ? Text(
                      _fmtDurationSummary(set.durationSeconds!),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.paper,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l.wdhlCount(set.reps),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.paper,
                            ),
                          ),
                          if (weightText.isNotEmpty)
                            TextSpan(
                              text: weightText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.paper.withValues(alpha: 0.48),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: rpeColor.withValues(alpha: 0.85),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'RPE ${_fmtNum(set.rpe)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.paper.withValues(alpha: 0.48),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.edit_outlined,
              size: 13,
              color: AppColors.paper.withValues(alpha: 0.20),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reflection card ─────────────────────────────────────────────────

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({
    required this.readiness,
    required this.soreness,
    required this.notes,
    required this.onReadiness,
    required this.onSoreness,
  });

  final int readiness;
  final int soreness;
  final TextEditingController notes;
  final ValueChanged<int> onReadiness;
  final ValueChanged<int> onSoreness;

  List<String> _readinessLabels(AppLocalizations l) => [
    '—',
    l.readinessSehrNiedrig,
    l.readinessNiedrig,
    l.readinessOk,
    l.readinessGut,
    l.readinessTop,
  ];

  List<String> _sorenessLabels(AppLocalizations l) => [
    '—',
    l.sorenessKeine,
    l.sorenessLeicht,
    l.sorenessModerat,
    l.sorenessStark,
    l.sorenessSehrStark,
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final border = AppColors.paper.withValues(alpha: 0.06);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + scales
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.nachbericht,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: AppColors.paper.withValues(alpha: 0.28),
                  ),
                ),
                const SizedBox(height: 14),
                _DotScaleRow(
                  label: l.readinessLabel,
                  description: _readinessLabels(l)[readiness.clamp(0, 5)],
                  value: readiness,
                  color: AppColors.sage,
                  onChanged: onReadiness,
                ),
                const SizedBox(height: 16),
                _DotScaleRow(
                  label: l.sorenessLabel,
                  description: _sorenessLabels(l)[soreness.clamp(0, 5)],
                  value: soreness,
                  color: AppColors.gold,
                  onChanged: onSoreness,
                ),
              ],
            ),
          ),
          // Notes field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: TextField(
              controller: notes,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.paper,
                height: 1.6,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: l.allgemeineNotizenHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: AppColors.paper.withValues(alpha: 0.28),
                ),
              ),
              cursorColor: AppColors.sage,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotScaleRow extends StatelessWidget {
  const _DotScaleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final String description;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.paper,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.paper.withValues(alpha: 0.48),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 1; i <= 5; i++) ...[
              _DotButton(
                index: i,
                selected: i <= value,
                color: color,
                onTap: () => onChanged(i),
              ),
              if (i < 5) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _DotButton extends StatelessWidget {
  const _DotButton({
    required this.index,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? color : AppColors.surface3,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? color
                    : AppColors.paper.withValues(alpha: 0.06),
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$index',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: index == (selected ? index : 0)
                  ? AppColors.paper
                  : AppColors.paper.withValues(alpha: 0.28),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Send button ─────────────────────────────────────────────────────

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sent, required this.onSend});

  final bool sent;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (sent) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.sage.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sage.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check, color: AppColors.sage, size: 18),
            const SizedBox(width: 10),
            Text(
              l.gesendetLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: AppColors.sage,
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: onSend,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send, size: 16),
            const SizedBox(width: 10),
            Text(
              l.zumCoachSenden,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

String _fmtDuration(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

Color _rpeColorForValue(double rpe) {
  if (rpe <= 4) return AppColors.sage;
  if (rpe <= 6) return AppColors.gold;
  return AppColors.coral;
}

String _fmtDurationSummary(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return s == 0 ? '$m min' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
