part of 'dashboard.dart';

// Coach hub: plan, goals, memory, and server-sync tabs.
// Library part of dashboard.dart (shared private scope, zero behavior change).

// ─── Coach Hub ──────────────────────────────────────────────────────────────

class _CoachPage extends StatefulWidget {
  const _CoachPage({required this.controller});

  final FitnessController controller;

  @override
  State<_CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<_CoachPage> {
  int _tab = 0; // 0 = Plan, 1 = Memory, 2 = Sync

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data;
    final block = widget.controller.activeBlock;

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
            hasSyncBadge: widget.controller.hasPendingCoachBlock,
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

  final FitnessController controller;
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
        _ChatEntryCard(onTap: () => _openCoachChat(context, controller)),
        const SizedBox(height: 8),
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

// ─── Chat Entry Card ──────────────────────────────────────────────────────

class _ChatEntryCard extends StatelessWidget {
  const _ChatEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.sage.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  size: 20,
                  color: AppColors.paper,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.chatCardTitle,
                      style: const TextStyle(
                        fontSize: AppType.callout,
                        fontWeight: FontWeight.w800,
                        color: AppColors.paper,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.chatCardSubtitle,
                      style: TextStyle(
                        fontSize: AppType.footnote,
                        color: AppColors.paper.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.paper.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
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

  final FitnessController controller;
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
                  style: const TextStyle(
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
                    style: const TextStyle(
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
                                  style: const TextStyle(
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
                            style: const TextStyle(
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
                  onTap: () {
                    Haptics.action();
                    widget.controller.startCurrentWorkout();
                  },
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
                style: const TextStyle(
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
    const paper = AppColors.paper;

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
              style: const TextStyle(
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
    const paper = AppColors.paper;
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
              style: const TextStyle(
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

  final FitnessController controller;
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

  final FitnessController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final bridge = controller.bridgeConfig;
    final isConfigured = bridge.isConfigured;
    final hasPending = controller.hasPendingCoachBlock;

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
