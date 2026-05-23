import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../design/design_tokens.dart';
import '../models/fitness_models.dart';
import '../state/fitness_controller.dart';
import 'set_log_modal.dart';

/// Full-screen route wrapper. Used when summary should appear as a
/// dedicated route (e.g. tapping a historical workout). Embedded inline
/// on the Today page, use [WorkoutSummaryView] directly.
class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key, required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Workout Summary',
          style: TextStyle(fontWeight: FontWeight.w900),
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

/// Inline summary widget. Lists totals, per-exercise rows (with set
/// editing + per-exercise notes), and a reflection block (readiness,
/// soreness, notes). Tapping the done button persists everything via
/// the controller; if [onDone] is provided it is invoked afterwards
/// (e.g. to pop a route).
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

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController();
    _notes.addListener(_onNotesChanged);
  }

  void _onNotesChanged() {
    // Rebuild so the dirty check (and thus the Save button visibility)
    // tracks live edits.
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
    final controller = FitnessScope.of(context);
    final log = _findLog(controller);
    if (log == null) {
      return const Center(child: Text('Workout not found'));
    }
    if (!_seeded) {
      _readiness = log.readiness;
      _soreness = log.soreness;
      _notes.text = log.notes;
      _seeded = true;
    }

    final totalSets = log.sets.length;
    final volume = log.totalVolume.toStringAsFixed(0);
    final totalActive = log.totalDurationSeconds ?? 0;
    final hr = log.healthMetrics?.heartRateBpm;
    final kcal = log.healthMetrics?.activeEnergyKcal;
    final dateText = DateFormat('EEE, d. MMM • HH:mm').format(log.startedAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        _CompletedBanner(),
        const SizedBox(height: 14),
            Text(
              log.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
              ),
            ),
            const SizedBox(height: 16),
            _SummaryStatsCard(
              activeSeconds: totalActive,
              pausedSeconds: log.pausedSeconds,
              exercisesDone: log.exerciseTimings
                  .where((t) => t.isStopped)
                  .length,
              totalSets: totalSets,
              volume: volume,
              hrBpm: hr,
              kcal: kcal,
            ),
            const SizedBox(height: 18),
            const _Heading('Exercises'),
            const SizedBox(height: 6),
            ...log.exerciseTimings.map((t) {
              // Build (set, indexInLog) pairs so edits can address the
              // underlying log.sets list directly.
              final pairs = <_IndexedSet>[];
              for (var i = 0; i < log.sets.length; i++) {
                final s = log.sets[i];
                if (s.exerciseId == t.exerciseId) {
                  pairs.add(_IndexedSet(s, i));
                }
              }
              pairs.sort((a, b) => a.set.setNumber.compareTo(b.set.setNumber));
              return _ExerciseSummaryRow(
                logId: log.id,
                timing: t,
                indexedSets: pairs,
              );
            }),
            if (log.exerciseTimings.isEmpty)
              Text(
                'No exercise timings recorded.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
                ),
              ),
            const SizedBox(height: 22),
            const _Heading('Reflection'),
            const SizedBox(height: 8),
            _ScaleRow(
              label: 'Readiness',
              value: _readiness,
              onChanged: (v) => setState(() => _readiness = v),
            ),
            const SizedBox(height: 8),
            _ScaleRow(
              label: 'Soreness',
              value: _soreness,
              onChanged: (v) => setState(() => _soreness = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Cues, regressions, anything for the coach...',
              ),
            ),
        const SizedBox(height: 20),
        if (_isDirty(log) || widget.onDone != null)
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () async {
                // Drop focus first so any per-exercise notes TextFields
                // commit via their onFocusChange listener.
                FocusManager.instance.primaryFocus?.unfocus();
                await Future<void>.delayed(const Duration(milliseconds: 30));
                await controller.updateCompletedLog(
                  widget.logId,
                  notes: _notes.text.trim(),
                  readiness: _readiness,
                  soreness: _soreness,
                );
                if (!context.mounted) return;
                widget.onDone?.call();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                widget.onDone == null ? 'Speichern' : 'Fertig',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isDirty(WorkoutLog log) {
    return _notes.text.trim() != log.notes.trim() ||
        _readiness != log.readiness ||
        _soreness != log.soreness;
  }
}

class _CompletedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.sage.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.sage, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Heutiges Training abgeschlossen',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.sage,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
      ),
    );
  }
}

class _SummaryStatsCard extends StatelessWidget {
  const _SummaryStatsCard({
    required this.activeSeconds,
    required this.pausedSeconds,
    required this.exercisesDone,
    required this.totalSets,
    required this.volume,
    required this.hrBpm,
    required this.kcal,
  });

  final int activeSeconds;
  final int pausedSeconds;
  final int exercisesDone;
  final int totalSets;
  final String volume;
  final double? hrBpm;
  final double? kcal;

  @override
  Widget build(BuildContext context) {
    final activeText = _fmtDuration(activeSeconds);
    final pausedText = pausedSeconds > 0
        ? ' (+${_fmtDuration(pausedSeconds)} paused)'
        : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stat(label: 'Active time', value: '$activeText$pausedText'),
              const SizedBox(width: 16),
              _Stat(label: 'Exercises', value: '$exercisesDone'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(label: 'Sets', value: '$totalSets'),
              const SizedBox(width: 16),
              _Stat(label: 'Volume', value: '$volume kg'),
            ],
          ),
          if (hrBpm != null || kcal != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (hrBpm != null)
                  _Stat(label: 'Avg HR', value: '${hrBpm!.round()} bpm'),
                if (hrBpm != null && kcal != null) const SizedBox(width: 16),
                if (kcal != null)
                  _Stat(label: 'Kcal', value: '${kcal!.round()}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: AppColors.ink.withValues(alpha: AppOpacity.mutedText),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexedSet {
  const _IndexedSet(this.set, this.index);
  final LoggedSet set;
  final int index;
}

class _ExerciseSummaryRow extends StatefulWidget {
  const _ExerciseSummaryRow({
    required this.logId,
    required this.timing,
    required this.indexedSets,
  });

  final String logId;
  final ExerciseTiming timing;
  final List<_IndexedSet> indexedSets;

  @override
  State<_ExerciseSummaryRow> createState() => _ExerciseSummaryRowState();
}

class _ExerciseSummaryRowState extends State<_ExerciseSummaryRow> {
  late final TextEditingController _notes;
  String _committedNotes = '';

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(text: widget.timing.notes);
    _committedNotes = widget.timing.notes;
  }

  @override
  void didUpdateWidget(covariant _ExerciseSummaryRow old) {
    super.didUpdateWidget(old);
    // If controller-side notes changed (e.g. after persist), keep the field
    // in sync as long as the user hasn't typed something different.
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
    await FitnessScope.of(context).updateExerciseNotes(
      widget.logId,
      widget.timing.exerciseId,
      next,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = FitnessScope.of(context);
    final dur = widget.timing.durationSeconds;
    final durText = dur == null ? '--' : _fmtDuration(dur);
    final hr = widget.timing.healthSnapshot?.heartRateBpm;
    final muted = AppColors.ink.withValues(alpha: AppOpacity.mutedText);
    final hasPause = widget.timing.pausedSeconds > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.ink.withValues(alpha: AppOpacity.subtle),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.timing.exerciseName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                durText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          if (hr != null || hasPause)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (hr != null) 'HR ${hr.round()} bpm',
                  if (hasPause)
                    'paused ${_fmtDuration(widget.timing.pausedSeconds)}',
                ].join(' • '),
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ),
          const SizedBox(height: 6),
          if (widget.indexedSets.isEmpty)
            Text(
              'No sets logged — tap "Add set" to record one.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: muted,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final pair in widget.indexedSets)
                  _SetLine(
                    set: pair.set,
                    onEdit: () => _openEditSetDialog(
                      context,
                      controller,
                      pair,
                    ),
                  ),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => controller.addLoggedSet(
                widget.logId,
                exerciseId: widget.timing.exerciseId,
                exerciseName: widget.timing.exerciseName,
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add set'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.sage,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          Focus(
            onFocusChange: (has) {
              if (!has) _commitNotesIfChanged();
            },
            child: TextField(
              controller: _notes,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitNotesIfChanged(),
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                hintText: 'Notes for this exercise…',
                hintStyle: TextStyle(fontSize: 12, color: muted),
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
    final sameExercise = widget.indexedSets.map((p) => p.set).toList();
    final result = await showSetLogModal(
      context,
      exerciseName: pair.set.exerciseName,
      currentSetNumber: pair.set.setNumber,
      totalSets: sameExercise.isEmpty ? pair.set.setNumber : sameExercise.length,
      initialWeightKg: pair.set.weightKg,
      initialReps: pair.set.reps,
      initialRpe: pair.set.rpe,
      history: sameExercise.where((s) => s.setNumber != pair.set.setNumber).toList(),
      allowDelete: true,
      saveLabel: 'Speichern',
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

class _SetLine extends StatelessWidget {
  const _SetLine({required this.set, required this.onEdit});

  final LoggedSet set;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.ink.withValues(alpha: AppOpacity.mutedText);
    final weightText = set.weightKg == 0
        ? 'bodyweight'
        : '${_fmtNum(set.weightKg)} kg';
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                'S${set.setNumber}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: muted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${set.reps} × $weightText',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            Text(
              'RPE ${_fmtNum(set.rpe)}',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(width: 6),
            Icon(Icons.edit, size: 13, color: muted),
          ],
        ),
      ),
    );
  }
}

String _fmtNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}

class _ScaleRow extends StatelessWidget {
  const _ScaleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var i = 1; i <= 5; i++)
                ChoiceChip(
                  label: Text('$i'),
                  selected: i == value,
                  onSelected: (_) => onChanged(i),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ),
      ],
    );
  }
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
