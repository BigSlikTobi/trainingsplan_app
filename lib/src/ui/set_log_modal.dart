import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/fitness_models.dart';
import '../util/haptics.dart';

class SetLogResult {
  const SetLogResult.save({
    required this.weightKg,
    required this.reps,
    required this.rpe,
    this.durationSeconds,
  }) : delete = false;
  const SetLogResult.delete()
      : weightKg = 0,
        reps = 0,
        rpe = 0,
        durationSeconds = null,
        delete = true;

  final double weightKg;
  final int reps;
  final double rpe;
  final int? durationSeconds;
  final bool delete;
}

/// Bottom-sheet set logger — Variation A from the T4L design handoff.
/// Steppers (no keyboard) + color-coded RPE chips + session history strip.
Future<SetLogResult?> showSetLogModal(
  BuildContext context, {
  required String exerciseName,
  required int currentSetNumber,
  required int totalSets,
  required double initialWeightKg,
  required int initialReps,
  required double initialRpe,
  int? targetReps,
  double? targetWeightKg,
  double? targetRpe,
  TrackingMode trackingMode = TrackingMode.weightAndReps,
  int? targetDurationSeconds,
  int? initialDurationSeconds,
  List<LoggedSet> history = const [],
  bool allowDelete = false,
  String? saveLabel,
}) {
  return showModalBottomSheet<SetLogResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x70181F1B),
    builder: (ctx) => _SetLogSheet(
      exerciseName: exerciseName,
      currentSetNumber: currentSetNumber,
      totalSets: totalSets,
      initialWeightKg: initialWeightKg,
      initialReps: initialReps,
      initialRpe: initialRpe,
      targetReps: targetReps,
      targetWeightKg: targetWeightKg,
      targetRpe: targetRpe,
      trackingMode: trackingMode,
      targetDurationSeconds: targetDurationSeconds,
      initialDurationSeconds: initialDurationSeconds,
      history: history,
      allowDelete: allowDelete,
      saveLabel: saveLabel,
    ),
  );
}

class _SetLogSheet extends StatefulWidget {
  const _SetLogSheet({
    required this.exerciseName,
    required this.currentSetNumber,
    required this.totalSets,
    required this.initialWeightKg,
    required this.initialReps,
    required this.initialRpe,
    required this.targetReps,
    required this.targetWeightKg,
    required this.targetRpe,
    required this.trackingMode,
    required this.targetDurationSeconds,
    required this.initialDurationSeconds,
    required this.history,
    required this.allowDelete,
    required this.saveLabel,
  });

  final String exerciseName;
  final int currentSetNumber;
  final int totalSets;
  final double initialWeightKg;
  final int initialReps;
  final double initialRpe;
  final int? targetReps;
  final double? targetWeightKg;
  final double? targetRpe;
  final TrackingMode trackingMode;
  final int? targetDurationSeconds;
  final int? initialDurationSeconds;
  final List<LoggedSet> history;
  final bool allowDelete;
  final String? saveLabel;

  @override
  State<_SetLogSheet> createState() => _SetLogSheetState();
}

class _SetLogSheetState extends State<_SetLogSheet> {
  late double _weight;
  late int _reps;
  late int _rpe;
  late int _durationSeconds;

  @override
  void initState() {
    super.initState();
    _weight = widget.initialWeightKg;
    _reps = widget.initialReps;
    _rpe = widget.initialRpe.round().clamp(6, 10);
    _durationSeconds =
        widget.initialDurationSeconds ??
        widget.targetDurationSeconds ??
        300;
  }

  SetLogResult _buildResult() {
    switch (widget.trackingMode) {
      case TrackingMode.timeOnly:
        return SetLogResult.save(
          weightKg: 0,
          reps: 0,
          rpe: 0,
          durationSeconds: _durationSeconds,
        );
      case TrackingMode.repsOnly:
        return SetLogResult.save(
          weightKg: 0,
          reps: _reps,
          rpe: _rpe.toDouble(),
        );
      case TrackingMode.weightAndReps:
        return SetLogResult.save(
          weightKg: _weight,
          reps: _reps,
          rpe: _rpe.toDouble(),
        );
    }
  }

  List<Widget> _buildInputs(AppLocalizations l) {
    switch (widget.trackingMode) {
      case TrackingMode.timeOnly:
        return [
          if (widget.targetDurationSeconds != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${l.zielLabel} ${_fmtDuration(widget.targetDurationSeconds!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.paper.withValues(alpha: 0.28),
                ),
              ),
            ),
          _Label(l.dialogSetDuration),
          _StepperRow(
            value: _durationSeconds.toDouble(),
            onChanged: (v) =>
                setState(() => _durationSeconds = v.round().clamp(0, 7200)),
            step: 30,
            min: 0,
            max: 7200,
            format: (v) => _fmtDuration(v.round()),
          ),
          const SizedBox(height: 18),
        ];
      case TrackingMode.repsOnly:
        return [
          _Label(l.statWdhl),
          _StepperRow(
            value: _reps.toDouble(),
            onChanged: (v) => setState(() => _reps = v.round()),
            step: 1,
            min: 1,
            max: 50,
            format: (v) => l.wdhlCount(v.round()),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Label(l.statRpe, noBottom: true),
              Flexible(
                child: Text(
                  _rpeDescriptions(l)[_rpe] ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.paper.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _RpeChips(value: _rpe, onChanged: (r) => setState(() => _rpe = r)),
          const SizedBox(height: 18),
        ];
      case TrackingMode.weightAndReps:
        return [
          _Label(l.dialogSetWeight),
          _StepperRow(
            value: _weight,
            onChanged: (v) => setState(() => _weight = v),
            step: 2.5,
            min: 0,
            max: 400,
            format: _fmtKg,
          ),
          const SizedBox(height: 10),
          _Label(l.statWdhl),
          _StepperRow(
            value: _reps.toDouble(),
            onChanged: (v) => setState(() => _reps = v.round()),
            step: 1,
            min: 1,
            max: 50,
            format: (v) => l.wdhlCount(v.round()),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Label(l.statRpe, noBottom: true),
              Flexible(
                child: Text(
                  _rpeDescriptions(l)[_rpe] ?? '',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.paper.withValues(alpha: 0.28),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _RpeChips(value: _rpe, onChanged: (r) => setState(() => _rpe = r)),
          const SizedBox(height: 18),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.paper.withValues(alpha: 0.06)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 48,
              offset: Offset(0, -12),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Handle(),
            _Header(
              name: widget.exerciseName,
              currentSet: widget.currentSetNumber,
              totalSets: widget.totalSets,
            ),
            const SizedBox(height: 4),
            _PrescriptionLine(
              totalSets: widget.totalSets,
              reps: widget.targetReps,
              weightKg: widget.targetWeightKg,
              rpe: widget.targetRpe,
              trackingMode: widget.trackingMode,
              targetDurationSeconds: widget.targetDurationSeconds,
            ),
            const SizedBox(height: 14),
            _HistoryStrip(
              history: widget.history,
              trackingMode: widget.trackingMode,
            ),
            ..._buildInputs(l),
            Row(
              children: [
                if (widget.allowDelete) ...[
                  _DeleteIconButton(
                    onTap: () {
                      Haptics.warning();
                      Navigator.of(context).pop(const SetLogResult.delete());
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _LogButton(
                    label: widget.saveLabel ?? l.btnSatzLoggen,
                    onTap: () {
                      Haptics.selection();
                      Navigator.of(context).pop(_buildResult());
                    },
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

// ─── Sub-widgets ────────────────────────────────────────────────────

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.currentSet,
    required this.totalSets,
  });
  final String name;
  final int currentSet;
  final int totalSets;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            name.toUpperCase(),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: AppColors.paper,
              letterSpacing: -0.2,
              height: 1.05,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.45)),
          ),
          child: Text(
            l.satzVonTotal(currentSet, totalSets),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.sage,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrescriptionLine extends StatelessWidget {
  const _PrescriptionLine({
    required this.totalSets,
    required this.reps,
    required this.weightKg,
    required this.rpe,
    this.trackingMode = TrackingMode.weightAndReps,
    this.targetDurationSeconds,
  });
  final int totalSets;
  final int? reps;
  final double? weightKg;
  final double? rpe;
  final TrackingMode trackingMode;
  final int? targetDurationSeconds;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (trackingMode == TrackingMode.timeOnly && targetDurationSeconds != null) {
      return Text(
        '${l.zielLabel} ${_fmtDuration(targetDurationSeconds!)}',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.paper.withValues(alpha: 0.28),
        ),
      );
    }
    final parts = <String>['$totalSets ×'];
    if (reps != null) parts.add(l.wdhlCount(reps!));
    if (trackingMode == TrackingMode.weightAndReps && weightKg != null) {
      parts[parts.length - 1] += ' · ${_fmtKg(weightKg!)}';
    }
    if (trackingMode != TrackingMode.timeOnly && rpe != null) {
      parts.add('RPE ${rpe!.toStringAsFixed(0)}');
    }
    return Text(
      '${l.zielLabel} ${parts.join(' · ')}',
      style: TextStyle(
        fontSize: 12,
        color: AppColors.paper.withValues(alpha: 0.28),
      ),
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({
    required this.history,
    this.trackingMode = TrackingMode.weightAndReps,
  });
  final List<LoggedSet> history;
  final TrackingMode trackingMode;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final muted = AppColors.paper.withValues(alpha: 0.28);
    final sorted = [...history]
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              l.heuteLabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: muted,
              ),
            ),
            const SizedBox(width: 10),
            for (final s in sorted) ...[
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: s.isTimeBased
                          ? 'S${s.setNumber}: ${_fmtDuration(s.durationSeconds!)}  '
                          : trackingMode == TrackingMode.repsOnly
                              ? 'S${s.setNumber}: ${s.reps} reps  '
                              : 'S${s.setNumber}: ${s.reps} × ${_fmtKg(s.weightKg)}  ',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.paper,
                      ),
                    ),
                    if (!s.isTimeBased)
                      TextSpan(
                        text: 'RPE ${s.rpe.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _rpeColor(s.rpe.round()),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.noBottom = false});
  final String text;
  final bool noBottom;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: noBottom ? 0 : 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: AppColors.paper.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.value,
    required this.onChanged,
    required this.step,
    required this.min,
    required this.max,
    required this.format,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.paper.withValues(alpha: 0.06);
    const faint = AppColors.surface2;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          _StepButton(
            width: 52,
            background: faint,
            borderRightColor: borderColor,
            label: '−',
            color: AppColors.paper,
            onTap: () {
              final next = (value - step).clamp(min, max);
              if (next != value) onChanged(_round(next));
            },
          ),
          Expanded(
            child: Container(
              color: AppColors.surface3,
              alignment: Alignment.center,
              child: Text(
                format(value),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.paper,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          _StepButton(
            width: 52,
            background: AppColors.sage,
            label: '+',
            color: AppColors.paper,
            onTap: () {
              final next = (value + step).clamp(min, max);
              if (next != value) onChanged(_round(next));
            },
          ),
        ],
      ),
    );
  }

  static double _round(double v) => (v * 10000).round() / 10000;
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.width,
    required this.background,
    required this.label,
    required this.color,
    required this.onTap,
    this.borderRightColor,
  });
  final double width;
  final Color background;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Color? borderRightColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          border: borderRightColor != null
              ? Border(right: BorderSide(color: borderRightColor!))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 22,
            color: color,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _RpeChips extends StatelessWidget {
  const _RpeChips({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final r in const [6, 7, 8, 9, 10]) ...[
          if (r != 6) const SizedBox(width: 6),
          Expanded(
            child: _RpeChip(value: r, selected: r == value, onTap: onChanged),
          ),
        ],
      ],
    );
  }
}

class _RpeChip extends StatelessWidget {
  const _RpeChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });
  final int value;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final color = _rpeColor(value);
    final bg = selected ? color : color.withValues(alpha: 0.10);
    final borderColor = selected ? color : color.withValues(alpha: 0.27);
    final numberColor = selected ? AppColors.white : color;
    final ridLabel = _rpeRir[value]!;
    final ridColor = selected
        ? Colors.white.withValues(alpha: 0.65)
        : color.withValues(alpha: 0.60);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        transform: selected
            ? (Matrix4.identity()..scaleByDouble(1.04, 1.04, 1.0, 1.0))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w900,
                color: numberColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ridLabel,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: ridColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  const _LogButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.bg,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _DeleteIconButton extends StatelessWidget {
  const _DeleteIconButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.coral.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.coral,
          size: 22,
        ),
      ),
    );
  }
}

// ─── tokens ─────────────────────────────────────────────────────────

const Map<int, String> _rpeRir = {
  6: '4 RIR',
  7: '3 RIR',
  8: '2 RIR',
  9: '1 RIR',
  10: '0 RIR',
};

Map<int, String> _rpeDescriptions(AppLocalizations l) => {
  6: l.rpeDescription6,
  7: l.rpeDescription7,
  8: l.rpeDescription8,
  9: l.rpeDescription9,
  10: l.rpeDescription10,
};

Color _rpeColor(int rpe) {
  switch (rpe.clamp(6, 10)) {
    case 6:
      return const Color(0xFF6E8A73);
    case 7:
      return const Color(0xFF7B9E60);
    case 8:
      return const Color(0xFFE8B35E);
    case 9:
      return const Color(0xFFD4834A);
    case 10:
      return const Color(0xFFCB6B52);
  }
  return AppColors.sage;
}

String _fmtKg(double v) {
  final n = v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1);
  return '$n kg';
}

String _fmtDuration(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return s == 0 ? '$m min' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
