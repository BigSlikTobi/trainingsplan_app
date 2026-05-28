part of 'dashboard.dart';

// Progress tab: volume, Apple Health charts, strength PRs, and readiness.
// Extracted from dashboard.dart as a library part to break up the monolith
// while preserving the shared private widget scope (zero behavior change).

class _ProgressPage extends StatefulWidget {
  const _ProgressPage({required this.controller});

  final FitnessController controller;

  @override
  State<_ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<_ProgressPage> {
  bool _daily = false;
  String _range = '4W';

  @override
  Widget build(BuildContext context) {
    final data = widget.controller.data;
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

  final FitnessController controller;
  final List<WorkoutLog> logs;

  @override
  State<_StrengthPRs> createState() => _StrengthPRsState();
}

class _StrengthPRsState extends State<_StrengthPRs> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final data = widget.controller.data;
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
  FitnessController controller, {
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

