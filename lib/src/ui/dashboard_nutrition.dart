part of 'dashboard.dart';

// Nutrition tab: fuel signal, advice, fuel diary, and meal analysis.
// Library part of dashboard.dart (shared private scope, zero behavior change).

class _NutritionPage extends StatelessWidget {
  const _NutritionPage({required this.controller});

  final FitnessController controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final profile = data.profile;
    final target = profile.nutritionTarget;
    final workout = controller.nextWorkout;
    final latest = data.nutrition.isEmpty ? null : data.nutrition.first;
    final guidance = controller.fuelGuidance;
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

