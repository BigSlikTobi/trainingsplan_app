import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/local_store.dart';
import '../data/seed_data.dart';
import '../models/fitness_models.dart';
import '../services/coach_payload_service.dart';
import '../services/health_sync_service.dart';
import '../services/local_bridge_service.dart';
import '../services/media_capture_service.dart';
import '../services/watch_sync_service.dart';
import '../util/app_log.dart';

/// Outcome of attempting to apply a single coach result pulled from the server.
///
/// The distinction drives whether the artifact is consumed on the server:
/// [applied] and [rejected] are both terminal (consume so they never re-appear),
/// while [awaitingUser] and [unknownKind] deliberately leave the artifact
/// pending. [rejected] specifically prevents a malformed payload from wedging
/// the pull loop by re-downloading and re-failing forever.
enum _ResultImport { applied, awaitingUser, rejected, unknownKind }

class FitnessController extends ChangeNotifier {
  FitnessController({
    LocalFitnessStore? store,
    HealthSyncService? health,
    MediaCaptureService? media,
    LocalBridgeService? bridge,
    WatchSyncService? watchSync,
  }) : _store = store ?? LocalFitnessStore(),
       _health = health ?? HealthSyncService(),
       _media = media ?? MediaCaptureService(),
       _bridge = bridge ?? LocalBridgeService(),
       _watchSync = watchSync ?? WatchSyncService() {
    _coach = CoachPayloadService();
  }

  final LocalFitnessStore _store;
  final HealthSyncService _health;
  final MediaCaptureService _media;
  final LocalBridgeService _bridge;
  final WatchSyncService _watchSync;
  late final CoachPayloadService _coach;

  FitnessData _data = createEmptyFitnessData();
  bool _isLoading = true;
  bool _disposed = false;
  bool _hasPendingCoachBlock = false;
  bool _hasPendingNutritionAnalysis = false;
  bool _isHealthTracking = false;
  LiveHealthMetrics? _liveHealthMetrics;
  Timer? _healthPoller;
  Timer? _uiTicker;
  String _status = 'Loading local training data...';
  LocalBridgeConfig _bridgeConfig = const LocalBridgeConfig();

  /// The workout just completed this session, surfaced on Today (summary + set
  /// logging) instead of advancing to the next workout. Backed by the
  /// persisted [FitnessData.justCompletedLogId] so it survives an app relaunch
  /// and the watch→phone background hand-off, and bounded to *today* so a stale
  /// marker expires (the next day's workout then shows). Cleared on
  /// acknowledge / start-next / plan-import via the setter.
  WorkoutLog? get _justCompletedLog {
    final id = _data.justCompletedLogId;
    if (id == null) return null;
    for (final log in _data.logs) {
      if (log.id != id) continue;
      final completedAt = log.completedAt;
      if (completedAt == null) return null;
      return dateKey(completedAt) == dateKey(DateTime.now()) ? log : null;
    }
    return null;
  }

  set _justCompletedLog(WorkoutLog? log) {
    _data = _data.copyWith(justCompletedLogId: log?.id);
  }
  Map<String, dynamic>? _pendingTrainingBlockPlanPayload;
  CoachingGoals? _pendingTrainingBlockGoals;
  StreamSubscription<Map<String, dynamic>>? _watchEvents;
  String? _activeWatchSessionWorkoutId;
  final Map<String, int> _watchProgressRevisions = {};

  @visibleForTesting
  String? get debugActiveWatchSessionWorkoutId => _activeWatchSessionWorkoutId;

  /// True while an Apple Watch session owns the active workout's exercise
  /// lifecycle. In this state the phone mirrors the watch and suppresses its
  /// own start/stop controls so the two devices never drive the session in
  /// parallel. When no watch session is active this is false and the phone
  /// owns the workout (e.g. training without a watch).
  bool get isWatchControllingSession => _activeWatchSessionWorkoutId != null;

  /// Guards a phone-initiated workout/exercise mutation: while the watch owns
  /// the live session the phone defers to it (single source of truth) and the
  /// caller bails out. Returns true if the action was blocked.
  bool _deferToWatchSession() {
    if (_activeWatchSessionWorkoutId == null) return false;
    _status = 'Exercise control is active on your Apple Watch';
    notifyListeners();
    return true;
  }

  FitnessData get data => _data;
  bool get isLoading => _isLoading;
  bool get hasPendingCoachBlock => _hasPendingCoachBlock;
  bool get hasPendingNutritionAnalysis => _hasPendingNutritionAnalysis;
  bool get isHealthTracking => _isHealthTracking;
  LiveHealthMetrics? get liveHealthMetrics => _liveHealthMetrics;
  String get status => _status;
  TrainingBlock? get activeBlock => _data.activeBlock;
  PlannedWorkout? get nextWorkout => _data.nextWorkout;
  bool get hasActiveWorkout => _data.hasActiveWorkout;
  WorkoutLog? get activeWorkoutLog => _activeWorkoutLog();
  WorkoutLog? get justCompletedLog => _justCompletedLog;

  /// The workout completed for *today's* session — what the Today screen shows
  /// (summary + set logging) instead of presenting a workout to train again.
  ///
  /// Derived directly from the persisted logs by date, so it's robust across
  /// app relaunches and regardless of how the workout was finished (phone or
  /// watch) — unlike [justCompletedLog], it doesn't depend on a runtime marker
  /// being set, so a session finished earlier (or in a previous build) is still
  /// recognised. Null while a workout is active, or once the day rolls over
  /// (the next session then shows).
  WorkoutLog? get todaysCompletedWorkout {
    if (hasActiveWorkout) return null;
    final block = _data.activeBlock;
    if (block == null) return null;
    final todayKey = dateKey(DateTime.now());
    final blockWorkoutIds = block.workouts.map((w) => w.id).toSet();
    WorkoutLog? best;
    for (final log in _data.logs) {
      final completedAt = log.completedAt;
      if (completedAt == null) continue;
      if (dateKey(completedAt) != todayKey) continue;
      if (!blockWorkoutIds.contains(log.workoutId)) continue;
      if (best == null || completedAt.isAfter(best.completedAt!)) best = log;
    }
    return best;
  }

  /// Re-establishes the "just completed" marker on launch when today's session
  /// is already done but the persisted marker is missing (e.g. it was finished
  /// on the watch, or in a previous app launch / build), and pushes the done
  /// state to the watch so it stays consistent with the phone instead of
  /// re-opening the workout. Within a session, import / start-next clear the
  /// marker as usual, so this never fights the advance flow.
  void _restoreCompletedSessionMarker() {
    if (_data.justCompletedLogId != null) return;
    final completed = todaysCompletedWorkout;
    if (completed == null) return;
    _data = _data.copyWith(justCompletedLogId: completed.id);
    unawaited(syncWorkoutToWatch());
  }
  MealAnalysisRequest? get pendingMealRequest => _data.pendingMealRequest;
  MealAnalysisResult? get pendingMealResult => _data.pendingMealResult;
  FuelGuidance? get fuelGuidance => _data.fuelGuidance;
  FuelCheckIn? get latestFuelCheckIn => _data.latestFuelCheckIn;
  List<FuelDiaryEntry> get fuelDiary => _data.fuelDiary;
  DateTime? get fuelDiarySentAt => _data.fuelDiarySentAt;
  LocalBridgeConfig get bridgeConfig => _bridgeConfig;

  Future<void> syncWorkoutToWatch() async {
    // Priority:
    //   1) an active (uncompleted) log → sync that workout in active state
    //   2) the just-completed log → keep the watch on its Done card until the
    //      phone summary is acknowledged or a new plan arrives
    //   3) nextWorkout → normal planned-workout state
    //   4) most recent completed log → fallback when no next workout exists
    PlannedWorkout? workout;
    WorkoutLog? activeLog;
    WorkoutLog? completedLog;

    final active = _activeWorkoutLog();
    if (active != null) {
      workout = _findWorkoutById(active.workoutId);
      activeLog = active;
    } else if (_justCompletedLog?.completedAt != null) {
      final justCompleted = _justCompletedLog!;
      completedLog = justCompleted;
      workout = _findWorkoutById(justCompleted.workoutId);
    } else {
      workout = nextWorkout;
      if (workout == null) {
        final recent = _mostRecentCompletedLog();
        if (recent != null) {
          workout = _findWorkoutById(recent.workoutId);
          completedLog = recent;
        }
      }
    }
    if (workout == null) {
      _status = 'No workout available for Apple Watch sync';
      notifyListeners();
      return;
    }

    try {
      _status = await _watchSync.syncWorkout(
        workout: workout,
        activeLog: activeLog,
        completedLog: completedLog,
      );
    } on Object catch (error) {
      _status = 'Apple Watch sync failed: $error';
    }
    notifyListeners();
  }

  PlannedWorkout? _findWorkoutById(String workoutId) {
    for (final block in _data.blocks) {
      for (final workout in block.workouts) {
        if (workout.id == workoutId) return workout;
      }
    }
    return null;
  }

  WorkoutLog? _mostRecentCompletedLog() {
    WorkoutLog? best;
    for (final log in _data.logs) {
      if (log.completedAt == null) continue;
      if (best == null || log.completedAt!.isAfter(best.completedAt!)) {
        best = log;
      }
    }
    return best;
  }

  Future<void> handleWatchWorkoutCompleted(Map<String, dynamic> payload) async {
    final completion = _watchCompletionLog(payload);
    if (completion == null) {
      _status = 'Ignored invalid Apple Watch workout payload';
      notifyListeners();
      return;
    }
    if (_activeWatchSessionWorkoutId == completion.workoutId) {
      _activeWatchSessionWorkoutId = null;
    }

    final logs = [..._data.logs];
    final activeIndex = logs.indexWhere(
      (log) => log.workoutId == completion.workoutId && log.completedAt == null,
    );
    final completedIndex = logs.indexWhere(
      (log) => log.workoutId == completion.workoutId && log.completedAt != null,
    );

    if (activeIndex >= 0) {
      logs[activeIndex] = _mergeWatchCompletion(
        existing: logs[activeIndex],
        incoming: completion,
      );
    } else if (completedIndex >= 0) {
      final existing = logs[completedIndex];
      if (completion.sets.length <= existing.sets.length) {
        _markWatchCompletionHandled(payload);
        _status = 'Ignored duplicate Apple Watch workout';
        notifyListeners();
        return;
      }
      logs[completedIndex] = _mergeWatchCompletion(
        existing: existing,
        incoming: completion,
      );
    } else {
      logs.insert(0, completion);
    }

    _stopHealthPolling();
    _stopUiTicker();
    _data = _data.copyWith(logs: logs);
    final justCompleted = logs.firstWhere(
      (log) => log.workoutId == completion.workoutId && log.completedAt != null,
      orElse: () => completion,
    );
    _justCompletedLog = justCompleted;
    _captureWorkoutMemory(justCompleted);
    await _persist('Imported Apple Watch workout');
    await _exportDayContext(notify: false);
    // Push the completion back to the watch so its UI flips from "Start"
    // to "Done" without waiting for the next user-triggered sync.
    unawaited(syncWorkoutToWatch());

    _markWatchCompletionHandled(payload);
  }

  Future<void> handleWatchWorkoutProgress(Map<String, dynamic> payload) async {
    final progress = _watchProgressLog(payload);
    if (progress == null) {
      _status = 'Ignored invalid Apple Watch progress payload';
      notifyListeners();
      return;
    }
    if (progress.completedAt != null) {
      await handleWatchWorkoutCompleted(payload);
      return;
    }

    final revision = _payloadInt(payload['revision'], 0);
    if (revision > 0) {
      final lastRevision = _watchProgressRevisions[progress.workoutId] ?? 0;
      if (revision <= lastRevision) return;
      _watchProgressRevisions[progress.workoutId] = revision;
    }

    _activeWatchSessionWorkoutId = progress.workoutId;
    final logs = [..._data.logs];
    final activeIndex = logs.indexWhere(
      (log) => log.workoutId == progress.workoutId && log.completedAt == null,
    );
    final completedIndex = logs.indexWhere(
      (log) => log.workoutId == progress.workoutId && log.completedAt != null,
    );

    if (completedIndex >= 0) return;
    if (activeIndex >= 0) {
      logs[activeIndex] = _mergeWatchProgress(
        existing: logs[activeIndex],
        incoming: progress,
      );
    } else {
      logs.insert(0, progress);
    }

    _data = _data.copyWith(logs: logs);
    // The watch owns the live session while it streams progress, so don't echo
    // its own state back to it (it ignores echoes of its active session, and
    // the phone defers to it — see _deferToWatchSession).
    await _persist('Imported Apple Watch progress');
  }

  void _markWatchCompletionHandled(Map<String, dynamic> payload) {
    final completionId = payload['completionId'] as String?;
    if (completionId != null && completionId.isNotEmpty) {
      unawaited(_watchSync.markCompletionHandled(completionId));
    }
  }

  Future<void> addMemory({
    required MemoryCategory category,
    required String title,
    required String summary,
    String markdown = '',
    String source = 'manual',
    double confidence = 1,
    bool active = true,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedSummary = summary.trim();
    if (trimmedTitle.isEmpty || trimmedSummary.isEmpty) {
      _status = 'Memory needs a title and summary';
      notifyListeners();
      return;
    }
    final now = DateTime.now();
    final memory = MemoryEntry(
      id: newId('memory'),
      createdAt: now,
      updatedAt: now,
      category: category,
      title: trimmedTitle,
      summary: trimmedSummary,
      markdown: markdown.trim(),
      source: source,
      confidence: confidence.clamp(0, 1).toDouble(),
      active: active,
    );
    _data = _data.copyWith(memories: [memory, ..._data.memories]);
    await _persist('Memory added');
  }

  Future<void> updateMemory(MemoryEntry memory) async {
    final trimmedTitle = memory.title.trim();
    final trimmedSummary = memory.summary.trim();
    if (trimmedTitle.isEmpty || trimmedSummary.isEmpty) {
      _status = 'Memory needs a title and summary';
      notifyListeners();
      return;
    }
    final updated = memory.copyWith(
      updatedAt: DateTime.now(),
      title: trimmedTitle,
      summary: trimmedSummary,
      markdown: memory.markdown.trim(),
      confidence: memory.confidence.clamp(0, 1).toDouble(),
    );
    _data = _data.copyWith(
      memories: _data.memories
          .map((item) => item.id == updated.id ? updated : item)
          .toList(),
    );
    await _persist('Memory updated');
  }

  Future<void> deleteMemory(String id) async {
    _data = _data.copyWith(
      memories: _data.memories.where((item) => item.id != id).toList(),
    );
    await _persist('Memory deleted');
  }

  Future<void> toggleMemory(String id, bool active) async {
    _data = _data.copyWith(
      memories: _data.memories
          .map(
            (item) => item.id == id
                ? item.copyWith(updatedAt: DateTime.now(), active: active)
                : item,
          )
          .toList(),
    );
    await _persist(active ? 'Memory activated' : 'Memory paused');
  }

  Future<void> addPersonalRecord({
    required String exerciseName,
    required double weightKg,
    double? previousKg,
    bool includeInContext = true,
  }) async {
    if (exerciseName.trim().isEmpty || weightKg <= 0) return;
    final pr = PersonalRecord(
      id: newId('pr'),
      exerciseName: exerciseName.trim(),
      weightKg: weightKg,
      previousKg: previousKg,
      updatedAt: DateTime.now(),
      includeInContext: includeInContext,
    );
    _data = _data.copyWith(personalRecords: [pr, ..._data.personalRecords]);
    await _persist('PR added');
  }

  Future<void> updatePersonalRecord(PersonalRecord pr) async {
    if (pr.exerciseName.trim().isEmpty || pr.weightKg <= 0) return;
    final updated = pr.copyWith(updatedAt: DateTime.now());
    _data = _data.copyWith(
      personalRecords: _data.personalRecords
          .map((item) => item.id == updated.id ? updated : item)
          .toList(),
    );
    await _persist('PR updated');
  }

  Future<void> deletePersonalRecord(String id) async {
    _data = _data.copyWith(
      personalRecords: _data.personalRecords
          .where((item) => item.id != id)
          .toList(),
    );
    await _persist('PR deleted');
  }

  Future<void> togglePersonalRecordContext(String id, bool include) async {
    _data = _data.copyWith(
      personalRecords: _data.personalRecords
          .map(
            (item) =>
                item.id == id ? item.copyWith(includeInContext: include) : item,
          )
          .toList(),
    );
    await _persist(include ? 'PR added to context' : 'PR removed from context');
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _data = await _store.load();
    _bridgeConfig = await _store.loadBridgeConfig();
    _isLoading = false;
    _status = 'Local-first coaching data loaded';
    _restoreCompletedSessionMarker();
    try {
      _watchEvents ??= _watchSync.events.listen((event) {
        switch (event['type']) {
          case 'watchWorkoutCompleted':
            final payload = (event['payload'] as Map?)?.cast<String, dynamic>();
            if (payload != null) {
              unawaited(handleWatchWorkoutCompleted(payload));
            }
          case 'watchWorkoutProgress':
            final payload = (event['payload'] as Map?)?.cast<String, dynamic>();
            if (payload != null) {
              unawaited(handleWatchWorkoutProgress(payload));
            }
          case 'watchSessionActive':
            final workoutId = event['workoutId'] as String?;
            if (workoutId != null && workoutId.isNotEmpty) {
              _activeWatchSessionWorkoutId = workoutId;
            }
          case 'watchSessionEnded':
            _activeWatchSessionWorkoutId = null;
        }
      }, onError: (_) {});
    } on Object {
      _watchEvents = null;
    }
    notifyListeners();
    if (_bridgeConfig.isConfigured) {
      await checkForCoachUpdates();
    }
  }

  Future<String> exportDailySnapshot() async {
    if (!_bridgeConfig.isConfigured) {
      _status = 'Enter the self-hosted server URL and API key first';
      notifyListeners();
      return '';
    }
    final dayContext = await _exportDayContext(
      notify: false,
      includeSnapshot: false,
    );
    final dailySnapshot = _coach.buildDailySnapshot(_data);
    await _bridge.uploadDailySnapshot(_bridgeConfig, dailySnapshot);
    _status = 'Pushed T4L Gym Bro day context and daily snapshot';
    notifyListeners();
    return dayContext['dayKey'] as String? ?? '';
  }

  Future<void> importCoachBlockPlan() async {
    final payload = _pendingTrainingBlockPlanPayload;
    if (payload == null) {
      _status = 'No T4L Gym Bro training block found on the server';
      notifyListeners();
      return;
    }
    final block = _coach.parseTrainingBlockPlan(payload);
    _data = _data.copyWith(
      blocks: [block, ..._data.blocks],
      activeBlockId: block.id,
      coachDecisions: [
        CoachDecision(
          id: newId('decision'),
          createdAt: DateTime.now(),
          title: 'Imported T4L Gym Bro block',
          rationale:
              'T4L Gym Bro block import passed schema validation and is now the active plan.',
          safetyFlags: const [],
          accepted: true,
        ),
        ..._data.coachDecisions,
      ],
    );
    if (_pendingTrainingBlockGoals != null) {
      _data = _data.copyWith(coachingGoals: _pendingTrainingBlockGoals);
    }
    _pendingTrainingBlockPlanPayload = null;
    _pendingTrainingBlockGoals = null;
    _hasPendingCoachBlock = false;
    await _bridge.markResultConsumed(_bridgeConfig, 'training_block_plan');
    await _persist('Imported T4L Gym Bro block plan');
  }

  Future<void> _pullLock = Future.value();

  Future<void> checkForCoachUpdates() {
    _pullLock = _pullLock.then((_) => pullBridgeResults());
    return _pullLock;
  }

  Future<void> saveBridgeConfig({
    required String baseUrl,
    required String token,
  }) async {
    _bridgeConfig = _bridgeConfig.copyWith(
      baseUrl: baseUrl.trim(),
      token: token.trim(),
      clearLastSyncAt: true,
    );
    await _store.saveBridgeConfig(_bridgeConfig);
    _status = _bridgeConfig.isConfigured
        ? 'Self-hosted server settings saved'
        : 'Server URL and API key are required';
    notifyListeners();
  }

  Future<void> testBridgeConnection() async {
    if (!_bridgeConfig.isConfigured) {
      _status = 'Enter the self-hosted server URL and API key first';
      notifyListeners();
      return;
    }
    try {
      await _bridge.health(_bridgeConfig);
      _status = 'Self-hosted server connected';
    } on Object catch (error, stackTrace) {
      AppLog.warn(
        'Self-hosted server connection failed',
        error: error,
        stackTrace: stackTrace,
      );
      _status = 'Self-hosted server connection failed: $error';
    }
    notifyListeners();
  }

  Future<void> migrateToServer() async {
    if (!_bridgeConfig.isConfigured) {
      _status = 'Enter the self-hosted server URL and API key first';
      notifyListeners();
      return;
    }
    try {
      final dayContext = await _exportDayContext(
        notify: false,
        includeSnapshot: false,
      );
      final dailySnapshot = _coach.buildDailySnapshot(_data);
      await _bridge.uploadDailySnapshot(_bridgeConfig, dailySnapshot);
      await _bridge.uploadAppSnapshot(_bridgeConfig, {
        'schema': 't4l_app_snapshot.v1',
        'createdAt': DateTime.now().toIso8601String(),
        'fitnessData': _data.toJson(),
        'dayContext': dayContext,
        'dailySnapshot': dailySnapshot,
      });
      _bridgeConfig = _bridgeConfig.copyWith(lastSyncAt: DateTime.now());
      await _store.saveBridgeConfig(_bridgeConfig);
      _status =
          'Migrated local training snapshot to self-hosted server. Phone data unchanged.';
    } on Object catch (error, stackTrace) {
      AppLog.error(
        'Server migration failed',
        error: error,
        stackTrace: stackTrace,
      );
      _status = 'Server migration failed: $error';
    }
    notifyListeners();
  }

  Future<void> pushBridgeContext() async {
    if (!_bridgeConfig.isConfigured) {
      _status = 'Enter the self-hosted server URL and API key first';
      notifyListeners();
      return;
    }
    try {
      await _exportDayContext(notify: false, includeSnapshot: false);
      final dailySnapshot = _coach.buildDailySnapshot(_data);
      await _bridge.uploadProfile(_bridgeConfig, {
        'schema': 'athlete_profile.v1',
        'createdAt': DateTime.now().toIso8601String(),
        'profile': _data.profile.toJson(),
      });
      await _bridge.uploadDailySnapshot(_bridgeConfig, dailySnapshot);
      final uploaded = <String>[
        'athlete_profile',
        'day_context',
        'daily_snapshot',
      ];
      _bridgeConfig = _bridgeConfig.copyWith(lastSyncAt: DateTime.now());
      await _store.saveBridgeConfig(_bridgeConfig);
      _status = 'Pushed ${uploaded.join(', ')} to self-hosted server';
    } on Object catch (error, stackTrace) {
      AppLog.error('Server push failed', error: error, stackTrace: stackTrace);
      _status = 'Server push failed: $error';
    }
    notifyListeners();
  }

  Future<void> pullBridgeResults() async {
    if (!_bridgeConfig.isConfigured) {
      _status = 'Enter the self-hosted server URL and API key first';
      notifyListeners();
      return;
    }
    final applied = <String>[];
    final rejected = <String>[];
    var awaitingBlock = false;
    try {
      final pendingKinds = await _bridge.pendingResultKinds(_bridgeConfig);
      for (final kind in pendingKinds) {
        final payload = await _bridge.downloadResult(_bridgeConfig, kind);
        if (payload == null) continue;
        final outcome = await _importBridgeResult(kind, payload);
        switch (outcome) {
          case _ResultImport.applied:
            await _bridge.markResultConsumed(_bridgeConfig, kind);
            applied.add(kind);
          case _ResultImport.rejected:
            // A malformed payload will never parse, so consume it to stop it
            // re-appearing on every pull and wedging the loop forever. The
            // failure is surfaced below and logged via parse error reporting.
            await _bridge.markResultConsumed(_bridgeConfig, kind);
            rejected.add(kind);
          case _ResultImport.awaitingUser:
            // Training blocks require explicit user import; leave them pending.
            awaitingBlock = true;
          case _ResultImport.unknownKind:
            // A result this app version does not understand: leave it pending
            // so a future version can apply it. Forward compatibility.
            break;
        }
      }
      _bridgeConfig = _bridgeConfig.copyWith(lastSyncAt: DateTime.now());
      await _store.saveBridgeConfig(_bridgeConfig);
      _status = _composePullStatus(
        applied: applied,
        rejected: rejected,
        awaitingBlock: awaitingBlock,
      );
    } on Object catch (error, stackTrace) {
      // Transport/server errors are transient: do not consume anything, so the
      // next pull retries cleanly.
      AppLog.warn(
        'Server result check failed',
        error: error,
        stackTrace: stackTrace,
      );
      _status = 'Server result check failed: $error';
    }
    notifyListeners();
  }

  String _composePullStatus({
    required List<String> applied,
    required List<String> rejected,
    required bool awaitingBlock,
  }) {
    final parts = <String>[];
    if (applied.isNotEmpty) {
      parts.add('Pulled ${applied.join(', ')} from self-hosted server');
    }
    if (awaitingBlock) {
      parts.add('New T4L Gym Bro training block available');
    }
    if (rejected.isNotEmpty) {
      parts.add(
        'Discarded unreadable ${rejected.join(', ')} from the coach; '
        'ask it to resend.',
      );
    }
    return parts.join(' · ');
  }

  Future<_ResultImport> _importBridgeResult(
    String kind,
    Map<String, dynamic> payload,
  ) async {
    try {
      switch (kind) {
        case 'next_day_plan':
          final parsed = _coach.parseNextDayPlanWithContext(payload);
          await importNextDayWorkout(parsed.workout, source: 'T4L server');
          _data = _data.copyWith(
            dailyMotto: parsed.dailyMotto ?? _data.dailyMotto,
            yesterdaySummary: parsed.yesterdaySummary ?? _data.yesterdaySummary,
            coachingGoals: parsed.goals ?? _data.coachingGoals,
          );
          await _store.save(_data);
          return _ResultImport.applied;
        case 'training_block_plan':
          final parsed = _coach.parseTrainingBlockPlanWithContext(payload);
          _pendingTrainingBlockPlanPayload = payload;
          _pendingTrainingBlockGoals = parsed.goals;
          _hasPendingCoachBlock = true;
          return _ResultImport.awaitingUser;
        case 'nutrition_analysis_result':
          final result = _coach.parseNutritionAnalysisResult(payload);
          _data = _data.copyWith(pendingMealResult: result);
          _hasPendingNutritionAnalysis = true;
          await _store.save(_data);
          return _ResultImport.applied;
        case 'fuel_guidance':
          final guidance = _coach.parseFuelGuidance(payload);
          _data = _data.copyWith(fuelGuidance: guidance);
          await _store.save(_data);
          return _ResultImport.applied;
        default:
          return _ResultImport.unknownKind;
      }
    } on FormatException catch (error, stackTrace) {
      AppLog.warn(
        'Rejected unreadable $kind payload from server',
        error: error,
        stackTrace: stackTrace,
      );
      return _ResultImport.rejected;
    }
  }

  Future<void> importNextDayWorkout(
    PlannedWorkout workout, {
    String source = 'coach',
  }) async {
    final block = activeBlock;
    if (block == null) {
      final fallbackBlock = TrainingBlock(
        id: newId('block_daily'),
        style: TrainingStyle.custom,
        title: 'Daily Coach Plans',
        durationWeeks: 1,
        currentWeek: workout.week,
        weeklyFocus: [workout.focus],
        measurableTargets: const [],
        workouts: [workout],
        createdBy: source,
        createdAt: DateTime.now(),
      );
      _data = _data.copyWith(
        blocks: [fallbackBlock, ..._data.blocks],
        activeBlockId: fallbackBlock.id,
        coachDecisions: [
          CoachDecision(
            id: newId('decision'),
            createdAt: DateTime.now(),
            title: 'Imported next-day plan',
            rationale: workout.rationale,
            safetyFlags: const [],
            accepted: true,
          ),
          ..._data.coachDecisions,
        ],
      );
      _justCompletedLog = null;
      await _persist('Imported next-day plan from $source');
      unawaited(syncWorkoutToWatch());
      return;
    }
    final updatedBlock = block.copyWith(
      workouts: [
        workout,
        ...block.workouts.where((item) => item.id != workout.id),
      ],
    );
    _data = _data.copyWith(
      blocks: _data.blocks
          .map((item) => item.id == block.id ? updatedBlock : item)
          .toList(),
      coachDecisions: [
        CoachDecision(
          id: newId('decision'),
          createdAt: DateTime.now(),
          title: 'Imported next-day plan',
          rationale: workout.rationale,
          safetyFlags: const [],
          accepted: true,
        ),
        ..._data.coachDecisions,
      ],
    );
    _justCompletedLog = null;
    await _persist('Imported next-day plan from $source');
    unawaited(syncWorkoutToWatch());
  }

  Future<void> logSet(
    ExercisePrescription exercise,
    double weight,
    int reps,
    double rpe, {
    int? durationSeconds,
  }) async {
    final workout = nextWorkout;
    if (workout == null) return;
    final existingIndex = _data.logs.indexWhere(
      (log) => log.workoutId == workout.id && log.completedAt == null,
    );
    final log = existingIndex >= 0
        ? _data.logs[existingIndex]
        : WorkoutLog(
            id: newId('log'),
            workoutId: workout.id,
            title: workout.title,
            startedAt: DateTime.now(),
            completedAt: null,
            readiness: 3,
            soreness: 2,
            notes: '',
            sets: const [],
            healthWriteStatus: 'not_synced',
          );
    final set = LoggedSet(
      exerciseId: exercise.exerciseId,
      exerciseName: exercise.name,
      setNumber:
          log.sets
              .where((item) => item.exerciseId == exercise.exerciseId)
              .length +
          1,
      weightKg: weight,
      reps: reps,
      rpe: rpe.clamp(1, 10).toDouble(),
      durationSeconds: durationSeconds,
    );
    final updated = log.copyWith(sets: [...log.sets, set]);
    final logs = [..._data.logs];
    if (existingIndex >= 0) {
      logs[existingIndex] = updated;
    } else {
      logs.insert(0, updated);
    }
    _data = _data.copyWith(logs: logs);
    await _persist('Logged ${exercise.name} set');
    unawaited(syncWorkoutToWatch());
  }

  Future<void> startCurrentWorkout() async {
    if (_deferToWatchSession()) return;
    // Starting a new session means the user has moved past the previous
    // completion — release the watch from the "Done" parked state so it
    // syncs the new active workout.
    _justCompletedLog = null;
    final workout = nextWorkout;
    if (workout == null) {
      _status = 'No workout available to start';
      notifyListeners();
      return;
    }

    final activeIndex = _activeWorkoutLogIndex();
    final log = activeIndex >= 0
        ? _data.logs[activeIndex]
        : WorkoutLog(
            id: newId('log'),
            workoutId: workout.id,
            title: workout.title,
            startedAt: DateTime.now(),
            completedAt: null,
            readiness: 3,
            soreness: 2,
            notes: '',
            sets: const [],
            healthWriteStatus: 'live_tracking',
          );

    if (activeIndex < 0) {
      _data = _data.copyWith(logs: [log, ..._data.logs]);
      await _store.save(_data);
    }

    try {
      final granted = await _health.requestLiveWorkoutPermissions();
      if (!granted) {
        _status = 'HealthKit live permissions denied';
        notifyListeners();
        return;
      }
    } on Object catch (error) {
      _status = 'HealthKit live setup failed: $error';
      notifyListeners();
      return;
    }

    _isHealthTracking = true;
    _status = 'Workout started - live HealthKit tracking active';
    _startHealthPolling();
    _startUiTicker();
    notifyListeners();
    await refreshLiveHealthMetrics();
    unawaited(syncWorkoutToWatch());
  }

  Future<void> startExerciseTimer({
    required String exerciseId,
    required String exerciseName,
  }) async {
    if (_deferToWatchSession()) return;
    final index = _activeWorkoutLogIndex();
    if (index < 0) {
      _status = 'Start the workout before timing an exercise';
      notifyListeners();
      return;
    }
    final log = _data.logs[index];
    final hasTiming = log.exerciseTimings.any(
      (t) => t.exerciseId == exerciseId,
    );
    if (hasTiming) return;

    final timing = ExerciseTiming(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      startedAt: DateTime.now(),
    );
    final updated = log.copyWith(
      exerciseTimings: [...log.exerciseTimings, timing],
    );
    final logs = [..._data.logs]..[index] = updated;
    _data = _data.copyWith(logs: logs);
    await _persist('Started timer: $exerciseName');
    unawaited(syncWorkoutToWatch());
  }

  Future<void> pauseExerciseTimer(String exerciseId) async {
    if (_deferToWatchSession()) return;
    final mutated = _mutateActiveExerciseTiming(
      exerciseId,
      (t) => t.isRunning ? t.copyWith(pausedAt: DateTime.now()) : null,
    );
    if (mutated != null) {
      await _persist('Paused timer: ${mutated.exerciseName}');
      unawaited(syncWorkoutToWatch());
    }
  }

  Future<void> resumeExerciseTimer(String exerciseId) async {
    if (_deferToWatchSession()) return;
    final mutated = _mutateActiveExerciseTiming(exerciseId, (t) {
      if (!t.isPaused) return null;
      final added = DateTime.now().difference(t.pausedAt!).inSeconds;
      return t.copyWith(
        clearPausedAt: true,
        pausedSeconds: t.pausedSeconds + (added < 0 ? 0 : added),
      );
    });
    if (mutated != null) {
      await _persist('Resumed timer: ${mutated.exerciseName}');
      unawaited(syncWorkoutToWatch());
    }
  }

  Future<void> stopExerciseTimer(
    String exerciseId, {
    bool autoCloseWorkout = true,
  }) async {
    if (_deferToWatchSession()) return;
    final index = _activeWorkoutLogIndex();
    if (index < 0) return;
    final log = _data.logs[index];
    final timingIndex = log.exerciseTimings.indexWhere(
      (t) => t.exerciseId == exerciseId && !t.isStopped,
    );
    if (timingIndex < 0) return;
    final current = log.exerciseTimings[timingIndex];

    final now = DateTime.now();
    var pausedSeconds = current.pausedSeconds;
    if (current.isPaused) {
      final added = now.difference(current.pausedAt!).inSeconds;
      pausedSeconds += (added < 0 ? 0 : added);
    }

    LiveHealthMetrics? snapshot;
    try {
      snapshot = await _health.readLiveWorkoutMetrics(current.startedAt);
    } on Object {
      snapshot = null;
    }

    final stopped = current.copyWith(
      completedAt: now,
      clearPausedAt: true,
      pausedSeconds: pausedSeconds,
      healthSnapshot: snapshot,
    );
    final timings = [...log.exerciseTimings]..[timingIndex] = stopped;
    final updated = log.copyWith(exerciseTimings: timings);
    final logs = [..._data.logs]..[index] = updated;
    _data = _data.copyWith(logs: logs);
    await _persist('Stopped timer: ${current.exerciseName}');
    unawaited(syncWorkoutToWatch());
    if (autoCloseWorkout) await _maybeAutoCloseWorkout();
  }

  Future<void> tryAutoCloseWorkout() => _maybeAutoCloseWorkout();

  Future<void> pauseCurrentWorkout() async {
    if (_deferToWatchSession()) return;
    final index = _activeWorkoutLogIndex();
    if (index < 0) return;
    final log = _data.logs[index];
    if (!log.isRunning) return;
    final updated = log.copyWith(pausedAt: DateTime.now());
    final logs = [..._data.logs]..[index] = updated;
    _data = _data.copyWith(logs: logs);
    _stopHealthPolling(clearMetrics: false);
    await _persist('Workout paused');
    unawaited(syncWorkoutToWatch());
  }

  Future<void> resumeCurrentWorkout() async {
    if (_deferToWatchSession()) return;
    final index = _activeWorkoutLogIndex();
    if (index < 0) return;
    final log = _data.logs[index];
    if (!log.isPaused) return;
    final added = DateTime.now().difference(log.pausedAt!).inSeconds;
    final updated = log.copyWith(
      clearPausedAt: true,
      pausedSeconds: log.pausedSeconds + (added < 0 ? 0 : added),
    );
    final logs = [..._data.logs]..[index] = updated;
    _data = _data.copyWith(logs: logs);
    _isHealthTracking = true;
    _startHealthPolling();
    await _persist('Workout resumed');
    unawaited(syncWorkoutToWatch());
  }

  Duration? get activeSessionElapsed {
    final log = _activeWorkoutLog();
    if (log == null) return null;
    final now = DateTime.now();
    var paused = log.pausedSeconds;
    if (log.isPaused) {
      final extra = now.difference(log.pausedAt!).inSeconds;
      paused += (extra < 0 ? 0 : extra);
    }
    final wall = now.difference(log.startedAt).inSeconds;
    final active = wall - paused;
    return Duration(seconds: active < 0 ? 0 : active);
  }

  Duration? elapsedForExercise(String exerciseId) {
    final log = _activeWorkoutLog();
    if (log == null) return null;
    final i = log.exerciseTimings.indexWhere(
      (t) => t.exerciseId == exerciseId && !t.isStopped,
    );
    if (i < 0) return null;
    final t = log.exerciseTimings[i];
    final now = DateTime.now();
    var paused = t.pausedSeconds;
    if (t.isPaused) {
      final extra = now.difference(t.pausedAt!).inSeconds;
      paused += (extra < 0 ? 0 : extra);
    }
    final wall = now.difference(t.startedAt).inSeconds;
    final active = wall - paused;
    return Duration(seconds: active < 0 ? 0 : active);
  }

  ExerciseTiming? timingForExercise(String exerciseId) {
    final log = _activeWorkoutLog() ?? _justCompletedLog;
    if (log == null) return null;
    final i = log.exerciseTimings.indexWhere((t) => t.exerciseId == exerciseId);
    return i < 0 ? null : log.exerciseTimings[i];
  }

  bool isExerciseRunning(String exerciseId) =>
      timingForExercise(exerciseId)?.isRunning ?? false;
  bool isExercisePaused(String exerciseId) =>
      timingForExercise(exerciseId)?.isPaused ?? false;
  bool isExerciseStopped(String exerciseId) {
    final log = _activeWorkoutLog() ?? _justCompletedLog;
    if (log == null) return false;
    return log.exerciseTimings.any(
      (t) => t.exerciseId == exerciseId && t.isStopped,
    );
  }

  bool get sessionIsRunning => _activeWorkoutLog()?.isRunning ?? false;
  bool get sessionIsPaused => _activeWorkoutLog()?.isPaused ?? false;

  ExerciseTiming? _mutateActiveExerciseTiming(
    String exerciseId,
    ExerciseTiming? Function(ExerciseTiming) transform,
  ) {
    final index = _activeWorkoutLogIndex();
    if (index < 0) return null;
    final log = _data.logs[index];
    final timingIndex = log.exerciseTimings.indexWhere(
      (t) => t.exerciseId == exerciseId && !t.isStopped,
    );
    if (timingIndex < 0) return null;
    final updatedTiming = transform(log.exerciseTimings[timingIndex]);
    if (updatedTiming == null) return null;
    final timings = [...log.exerciseTimings]..[timingIndex] = updatedTiming;
    final updatedLog = log.copyWith(exerciseTimings: timings);
    final logs = [..._data.logs]..[index] = updatedLog;
    _data = _data.copyWith(logs: logs);
    return updatedTiming;
  }

  Future<void> _maybeAutoCloseWorkout() async {
    final workout = nextWorkout;
    final log = _activeWorkoutLog();
    if (workout == null || log == null) return;
    final stoppedIds = log.exerciseTimings
        .where((t) => t.isStopped)
        .map((t) => t.exerciseId)
        .toSet();
    final allDone = workout.exercises.every(
      (e) => stoppedIds.contains(e.exerciseId),
    );
    if (!allDone) return;
    await stopCurrentWorkout();
  }

  void clearJustCompleted() {
    if (_justCompletedLog == null) return;
    _justCompletedLog = null;
    notifyListeners();
    // Advance the watch to the next planned workout now that the user has
    // acknowledged the completed one on the phone.
    unawaited(syncWorkoutToWatch());
  }

  Future<void> updateCompletedLog(
    String logId, {
    String? notes,
    int? readiness,
    int? soreness,
  }) async {
    final index = _data.logs.indexWhere((l) => l.id == logId);
    if (index < 0) return;
    final updated = _data.logs[index].copyWith(
      notes: notes,
      readiness: readiness,
      soreness: soreness,
    );
    final logs = [..._data.logs]..[index] = updated;
    _data = _data.copyWith(logs: logs);
    if (_justCompletedLog?.id == logId) {
      _justCompletedLog = updated;
    }
    await _persist('Updated workout reflection');
    await _exportDayContext(notify: false);
  }

  Future<void> updateLoggedSet(
    String logId,
    int setIndex, {
    double? weightKg,
    int? reps,
    double? rpe,
  }) async {
    final logIdx = _data.logs.indexWhere((l) => l.id == logId);
    if (logIdx < 0) return;
    final log = _data.logs[logIdx];
    if (setIndex < 0 || setIndex >= log.sets.length) return;
    final old = log.sets[setIndex];
    final updatedSet = LoggedSet(
      exerciseId: old.exerciseId,
      exerciseName: old.exerciseName,
      setNumber: old.setNumber,
      weightKg: weightKg ?? old.weightKg,
      reps: reps ?? old.reps,
      rpe: (rpe ?? old.rpe).clamp(1, 10).toDouble(),
    );
    final sets = [...log.sets]..[setIndex] = updatedSet;
    await _saveLog(logIdx, log.copyWith(sets: sets), 'Updated set');
  }

  Future<void> addLoggedSet(
    String logId, {
    required String exerciseId,
    required String exerciseName,
    double weightKg = 0,
    int reps = 0,
    double rpe = 7,
  }) async {
    final logIdx = _data.logs.indexWhere((l) => l.id == logId);
    if (logIdx < 0) return;
    final log = _data.logs[logIdx];
    final setNumber =
        log.sets.where((s) => s.exerciseId == exerciseId).length + 1;
    final set = LoggedSet(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      rpe: rpe.clamp(1, 10).toDouble(),
    );
    await _saveLog(logIdx, log.copyWith(sets: [...log.sets, set]), 'Added set');
  }

  Future<void> removeLoggedSet(String logId, int setIndex) async {
    final logIdx = _data.logs.indexWhere((l) => l.id == logId);
    if (logIdx < 0) return;
    final log = _data.logs[logIdx];
    if (setIndex < 0 || setIndex >= log.sets.length) return;
    final removed = log.sets[setIndex];
    final remaining = [...log.sets]..removeAt(setIndex);
    // Renumber sets for the affected exercise so set numbers stay 1..N.
    var counter = 0;
    final renumbered = remaining.map((s) {
      if (s.exerciseId != removed.exerciseId) return s;
      counter += 1;
      return LoggedSet(
        exerciseId: s.exerciseId,
        exerciseName: s.exerciseName,
        setNumber: counter,
        weightKg: s.weightKg,
        reps: s.reps,
        rpe: s.rpe,
      );
    }).toList();
    await _saveLog(logIdx, log.copyWith(sets: renumbered), 'Removed set');
  }

  Future<void> updateExerciseNotes(
    String logId,
    String exerciseId,
    String notes,
  ) async {
    final logIdx = _data.logs.indexWhere((l) => l.id == logId);
    if (logIdx < 0) return;
    final log = _data.logs[logIdx];
    final tIdx = log.exerciseTimings.indexWhere(
      (t) => t.exerciseId == exerciseId,
    );
    if (tIdx < 0) return;
    final timings = [...log.exerciseTimings]
      ..[tIdx] = log.exerciseTimings[tIdx].copyWith(notes: notes);
    await _saveLog(
      logIdx,
      log.copyWith(exerciseTimings: timings),
      'Updated exercise notes',
    );
  }

  Future<void> removeWorkoutLog(String logId) async {
    final remaining = _data.logs.where((l) => l.id != logId).toList();
    if (remaining.length == _data.logs.length) return;
    _data = _data.copyWith(logs: remaining);
    if (_justCompletedLog?.id == logId) _justCompletedLog = null;
    await _persist('Deleted workout log');
    await _exportDayContext(notify: false);
  }

  Future<void> _saveLog(int logIdx, WorkoutLog updated, String status) async {
    final logs = [..._data.logs]..[logIdx] = updated;
    _data = _data.copyWith(logs: logs);
    if (_justCompletedLog?.id == updated.id) {
      _justCompletedLog = updated;
    }
    await _persist(status);
    await _exportDayContext(notify: false);
  }

  Future<void> stopCurrentWorkout({
    String notes = '',
    int readiness = 3,
    int soreness = 2,
  }) async {
    final index = _activeWorkoutLogIndex();
    if (index < 0) {
      _stopHealthPolling();
      _status = 'No active workout to stop';
      notifyListeners();
      return;
    }

    final finalHealthMetrics = _liveHealthMetrics;
    _stopHealthPolling();
    _stopUiTicker();
    final existing = _data.logs[index];
    final now = DateTime.now();
    final closedTimings = existing.exerciseTimings.map((t) {
      if (t.isStopped) return t;
      var paused = t.pausedSeconds;
      if (t.isPaused) {
        final extra = now.difference(t.pausedAt!).inSeconds;
        paused += (extra < 0 ? 0 : extra);
      }
      return t.copyWith(
        completedAt: now,
        clearPausedAt: true,
        pausedSeconds: paused,
      );
    }).toList();

    var sessionPaused = existing.pausedSeconds;
    if (existing.isPaused) {
      final extra = now.difference(existing.pausedAt!).inSeconds;
      sessionPaused += (extra < 0 ? 0 : extra);
    }

    var completed = existing.copyWith(
      completedAt: now,
      notes: notes,
      readiness: readiness,
      soreness: soreness,
      healthMetrics: finalHealthMetrics,
      exerciseTimings: closedTimings,
      clearPausedAt: true,
      pausedSeconds: sessionPaused,
    );
    completed = await _syncCompletedWorkout(completed);

    final logs = [..._data.logs]..[index] = completed;
    _data = _data.copyWith(logs: logs);
    _captureWorkoutMemory(completed);
    _justCompletedLog = completed;
    await _persist('Workout stopped and saved');
    await _exportDayContext(notify: false);
    unawaited(syncWorkoutToWatch());
  }

  Future<void> refreshLiveHealthMetrics() async {
    final log = _activeWorkoutLog();
    if (!_isHealthTracking || log == null) return;

    try {
      _liveHealthMetrics = await _health.readLiveWorkoutMetrics(log.startedAt);
    } on Object catch (error) {
      _status = 'Live HealthKit read failed: $error';
      _stopHealthPolling(clearMetrics: false);
    }
    notifyListeners();
  }

  Future<void> completeCurrentWorkout({
    String notes = '',
    int readiness = 3,
    int soreness = 2,
  }) async {
    final workout = nextWorkout;
    if (workout == null) {
      _status = 'No workout available to complete';
      notifyListeners();
      return;
    }
    final index = _data.logs.indexWhere(
      (log) => log.workoutId == workout.id && log.completedAt == null,
    );
    if (index < 0) {
      final now = DateTime.now();
      var completed = WorkoutLog(
        id: newId('log'),
        workoutId: workout.id,
        title: workout.title,
        startedAt: now,
        completedAt: now,
        readiness: readiness,
        soreness: soreness,
        notes: notes,
        sets: const [],
        healthWriteStatus: 'not_synced',
      );
      completed = await _syncCompletedWorkout(completed);
      _data = _data.copyWith(logs: [completed, ..._data.logs]);
      _captureWorkoutMemory(completed);
      _justCompletedLog = completed;
      await _persist('Completed ${workout.title}');
      await _exportDayContext(notify: false);
      unawaited(syncWorkoutToWatch());
      return;
    }
    if (_isHealthTracking || _data.logs[index].sets.isEmpty) {
      await stopCurrentWorkout(
        notes: notes,
        readiness: readiness,
        soreness: soreness,
      );
      return;
    }
    var completed = _data.logs[index].copyWith(
      completedAt: DateTime.now(),
      notes: notes,
      readiness: readiness,
      soreness: soreness,
    );
    completed = await _syncCompletedWorkout(completed);
    final logs = [..._data.logs]..[index] = completed;
    _data = _data.copyWith(logs: logs);
    _captureWorkoutMemory(completed);
    _justCompletedLog = completed;
    await _persist('Completed ${workout.title}');
    await _exportDayContext(notify: false);
    unawaited(syncWorkoutToWatch());
  }

  Future<void> saveNutrition(NutritionLog log) async {
    final key = dateKey(log.date);
    final filtered = _data.nutrition
        .where((item) => dateKey(item.date) != key)
        .toList();
    _data = _data.copyWith(nutrition: [log, ...filtered]);
    try {
      _status = await _health.writeNutrition(log);
    } on Object catch (error) {
      _status = 'Nutrition saved locally, HealthKit failed: $error';
    }
    await _store.save(_data);
    notifyListeners();
  }

  Future<void> submitFuelCheckIn({
    required String guidanceValidFor,
    required int score,
    String context = '',
  }) async {
    _data = _data.copyWith(
      latestFuelCheckIn: FuelCheckIn(
        guidanceValidFor: guidanceValidFor,
        score: score.clamp(1, 10),
        context: context.trim(),
        createdAt: DateTime.now(),
      ),
    );
    await _store.save(_data);
    try {
      if (_bridgeConfig.isConfigured) {
        await _exportDayContext(notify: false);
        _status = 'Sent Fuel check-in to T4L Gym Bro';
      } else {
        _status = 'Saved Fuel check-in locally';
      }
    } on Object catch (error) {
      _status = 'Fuel check-in saved locally, server push failed: $error';
    }
    notifyListeners();
  }

  Future<void> addFuelDiaryEntry(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final today = _todayKey();
    final entry = FuelDiaryEntry(
      id: newId('fuel_diary'),
      date: today,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    _data = _data.copyWith(fuelDiary: [..._data.fuelDiary, entry]);
    await _store.save(_data);
    notifyListeners();
  }

  Future<void> removeFuelDiaryEntry(String id) async {
    _data = _data.copyWith(
      fuelDiary: _data.fuelDiary.where((e) => e.id != id).toList(),
    );
    await _store.save(_data);
    notifyListeners();
  }

  List<FuelDiaryEntry> get todayFuelDiary {
    final today = _todayKey();
    return _data.fuelDiary.where((e) => e.date == today).toList();
  }

  bool get fuelDiarySentToday {
    final sent = _data.fuelDiarySentAt;
    if (sent == null) return false;
    final today = _todayKey();
    final sentKey =
        '${sent.year}-${sent.month.toString().padLeft(2, '0')}-${sent.day.toString().padLeft(2, '0')}';
    return sentKey == today;
  }

  Future<void> submitFuelDiary({required int score}) async {
    final entries = todayFuelDiary;
    if (entries.isEmpty) return;
    final combined = entries.map((e) => e.text).join('\n');
    _data = _data.copyWith(
      latestFuelCheckIn: FuelCheckIn(
        guidanceValidFor: _todayKey(),
        score: score.clamp(1, 10),
        context: combined,
        createdAt: DateTime.now(),
      ),
      fuelDiarySentAt: DateTime.now(),
    );
    await _store.save(_data);
    try {
      if (_bridgeConfig.isConfigured) {
        await _exportDayContext(notify: false);
        _status = 'Sent Fuel diary to T4L Gym Bro';
        unawaited(
          Future.delayed(const Duration(seconds: 5), () {
            if (_disposed) return;
            if (_bridgeConfig.isConfigured) {
              unawaited(checkForCoachUpdates());
            }
          }),
        );
      } else {
        _status = 'Saved Fuel diary locally';
      }
    } on Object catch (error, stackTrace) {
      AppLog.warn(
        'Fuel diary saved locally, server push failed',
        error: error,
        stackTrace: stackTrace,
      );
      _status = 'Fuel diary saved locally, server push failed: $error';
    }
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> updateProfile(AthleteProfile profile) async {
    _data = _data.copyWith(profile: profile);
    await _persist('Profile updated for T4L Gym Bro nutrition context');
  }

  Future<String?> pickMealImageFromGallery() {
    return _media.pickMealImageFromGallery();
  }

  Future<String?> pickMealImageFromCamera() {
    return _media.pickMealImageFromCamera();
  }

  Future<void> exportNutritionAnalysisRequest({
    required String description,
    String? imagePath,
  }) async {
    if (description.trim().isEmpty &&
        (imagePath == null || imagePath.trim().isEmpty)) {
      _status = 'Describe the meal or attach a photo before exporting';
      notifyListeners();
      return;
    }
    if (!_bridgeConfig.isConfigured) {
      _status = 'Enter the self-hosted server URL and API key first';
      notifyListeners();
      return;
    }
    await _exportDayContext(notify: false);
    final remoteImagePath = await _uploadMealImage(imagePath);
    final (request, payload) = _coach.buildNutritionAnalysisRequest(
      data: _data,
      description: description,
      imagePath: remoteImagePath,
    );
    await _bridge.uploadNutritionAnalysisRequest(_bridgeConfig, payload);
    _data = _data.copyWith(
      pendingMealRequest: request,
      pendingMealResult: null,
    );
    _hasPendingNutritionAnalysis = false;
    await _store.save(_data);
    _status = 'Sent meal analysis request to T4L Gym Bro';
    notifyListeners();
  }

  Future<void> checkForNutritionAnalysisResult() {
    return checkForCoachUpdates();
  }

  Future<void> acceptMealAnalysis({
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    required double bodyWeightKg,
    required String notes,
  }) async {
    final result = _data.pendingMealResult;
    if (result == null) {
      _status = 'No nutrition analysis result to accept';
      notifyListeners();
      return;
    }
    final accepted = MealAnalysisResult(
      id: result.id,
      requestId: result.requestId,
      analyzedAt: result.analyzedAt,
      mealDescription: result.mealDescription,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      bodyWeightKg: bodyWeightKg,
      confidence: result.confidence,
      assumptions: result.assumptions,
      rationale: result.rationale,
      correctionNotes: result.correctionNotes,
      target: result.target,
    );
    final target = accepted.target;
    _data = _data.copyWith(
      profile: target == null
          ? _data.profile.copyWith(weightKg: bodyWeightKg)
          : _data.profile.copyWith(
              weightKg: bodyWeightKg,
              nutritionTarget: target,
            ),
      pendingMealRequest: null,
      pendingMealResult: null,
    );
    _hasPendingNutritionAnalysis = false;
    _captureMealMemory(accepted, notes);
    await saveNutrition(accepted.toNutritionLog(notes: notes));
    _status = 'Accepted T4L Gym Bro nutrition analysis and saved calories';
    notifyListeners();
  }

  Future<void> discardMealAnalysis() async {
    _data = _data.copyWith(pendingMealRequest: null, pendingMealResult: null);
    _hasPendingNutritionAnalysis = false;
    await _persist('Discarded T4L Gym Bro nutrition analysis');
  }

  Future<void> connectHealth() async {
    try {
      _status = await _health.requestPermissions();
    } on Object catch (error, stackTrace) {
      AppLog.warn(
        'HealthKit setup failed',
        error: error,
        stackTrace: stackTrace,
      );
      _status = 'HealthKit setup failed: $error';
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    // Timers and delayed callbacks can fire after the controller is disposed
    // (e.g. the app is torn down mid-workout). Guarding here prevents the
    // "notifyListeners after dispose" assertion from any of the many call sites.
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_watchEvents?.cancel());
    _healthPoller?.cancel();
    _uiTicker?.cancel();
    super.dispose();
  }

  int _activeWorkoutLogIndex() {
    final workout = nextWorkout;
    if (workout == null) return -1;
    return _data.logs.indexWhere(
      (log) => log.workoutId == workout.id && log.completedAt == null,
    );
  }

  WorkoutLog? _activeWorkoutLog() {
    final index = _activeWorkoutLogIndex();
    return index < 0 ? null : _data.logs[index];
  }

  // ignore: unused_element
  void _startUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  void _stopUiTicker() {
    _uiTicker?.cancel();
    _uiTicker = null;
  }

  void _startHealthPolling() {
    _healthPoller?.cancel();
    _healthPoller = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(refreshLiveHealthMetrics()),
    );
  }

  void _stopHealthPolling({bool clearMetrics = true}) {
    _healthPoller?.cancel();
    _healthPoller = null;
    _isHealthTracking = false;
    if (clearMetrics) _liveHealthMetrics = null;
  }

  Future<WorkoutLog> _syncCompletedWorkout(WorkoutLog completed) async {
    if (_activeWatchSessionWorkoutId == completed.workoutId) {
      unawaited(_watchSync.endWatchWorkout(completed.workoutId));
      return completed.copyWith(healthWriteStatus: 'pending_watch_completion');
    }
    try {
      final match = await _health.readCompletedWorkoutMatch(completed);
      if (match != null) {
        return completed.copyWith(
          healthWriteStatus: match.status,
          healthMetrics: match.metrics,
        );
      }
      final healthStatus = await _health.writeWorkout(completed);
      return completed.copyWith(healthWriteStatus: healthStatus);
    } on Object catch (error) {
      return completed.copyWith(healthWriteStatus: 'health_error: $error');
    }
  }

  Future<Map<String, dynamic>> _exportDayContext({
    bool notify = true,
    bool includeSnapshot = true,
  }) async {
    final now = DateTime.now();
    final activityReport = await _health.readDayActivityReport(now);
    final payload = _coach.buildDayContext(
      data: _data,
      activityReport: activityReport,
      day: now,
    );
    if (_bridgeConfig.isConfigured) {
      await _bridge.uploadDayContext(_bridgeConfig, payload);
      // Refresh the daily snapshot alongside the day context so the coach's
      // recent-history view (recentLogs) stays current after every workout or
      // fuel event, without waiting for a manual Context Push. Best-effort: a
      // snapshot failure must not break the flow that triggered it. Callers
      // that upload the snapshot themselves pass includeSnapshot: false.
      if (includeSnapshot) {
        try {
          await _bridge.uploadDailySnapshot(
            _bridgeConfig,
            _coach.buildDailySnapshot(_data),
          );
        } on Object catch (error, stackTrace) {
          AppLog.warn(
            'Daily snapshot refresh failed',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }
    if (notify) {
      _status = _bridgeConfig.isConfigured
          ? 'Pushed day context to T4L Gym Bro'
          : 'Enter the self-hosted server URL and API key first';
      notifyListeners();
    }
    return payload;
  }

  Future<String?> _uploadMealImage(String? imagePath) async {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    final source = File(imagePath.trim());
    if (!source.existsSync()) return imagePath.trim();
    final extension = p.extension(source.path).isEmpty
        ? '.jpg'
        : p.extension(source.path);
    final fileName = '${newId('meal_image')}$extension';
    await _bridge.uploadMealImage(
      _bridgeConfig,
      fileName,
      await source.readAsBytes(),
    );
    return 'meal_images/$fileName';
  }

  WorkoutLog? _watchCompletionLog(Map<String, dynamic> payload) {
    if (payload['schemaVersion'] != WatchSyncService.schemaVersion) {
      return null;
    }
    final workoutId = payload['workoutId'] as String? ?? '';
    if (workoutId.isEmpty) return null;
    final startedAt = DateTime.tryParse(payload['startedAt'] as String? ?? '');
    final completedAt = DateTime.tryParse(
      payload['completedAt'] as String? ?? '',
    );
    if (startedAt == null || completedAt == null) return null;

    final title =
        payload['title'] as String? ?? nextWorkout?.title ?? 'Workout';
    return WorkoutLog(
      id: payload['logId'] as String? ?? newId('watch_log'),
      workoutId: workoutId,
      title: title,
      startedAt: startedAt,
      completedAt: completedAt,
      readiness: _payloadInt(payload['readiness'], 3),
      soreness: _payloadInt(payload['soreness'], 2),
      notes: payload['notes'] as String? ?? '',
      sets: _payloadObjects(payload['sets'], LoggedSet.fromJson),
      healthWriteStatus:
          payload['healthWriteStatus'] as String? ?? 'watch_health_unavailable',
      healthMetrics: _payloadObject(
        payload['healthMetrics'],
        LiveHealthMetrics.fromJson,
      ),
      exerciseTimings: _payloadObjects(
        payload['exerciseTimings'],
        ExerciseTiming.fromJson,
      ),
      pausedSeconds: _payloadInt(payload['pausedSeconds'], 0),
    );
  }

  WorkoutLog? _watchProgressLog(Map<String, dynamic> payload) {
    if (payload['schemaVersion'] != WatchSyncService.schemaVersion) {
      return null;
    }
    final workoutId = payload['workoutId'] as String? ?? '';
    if (workoutId.isEmpty) return null;
    final startedAt = DateTime.tryParse(payload['startedAt'] as String? ?? '');
    if (startedAt == null) return null;

    final title =
        payload['title'] as String? ?? nextWorkout?.title ?? 'Workout';
    return WorkoutLog(
      id: payload['logId'] as String? ?? newId('watch_log'),
      workoutId: workoutId,
      title: title,
      startedAt: startedAt,
      completedAt: DateTime.tryParse(payload['completedAt'] as String? ?? ''),
      pausedAt: DateTime.tryParse(payload['pausedAt'] as String? ?? ''),
      readiness: _payloadInt(payload['readiness'], 3),
      soreness: _payloadInt(payload['soreness'], 2),
      notes: payload['notes'] as String? ?? '',
      sets: _payloadObjects(payload['sets'], LoggedSet.fromJson),
      healthWriteStatus:
          payload['healthWriteStatus'] as String? ?? 'watch_progress',
      healthMetrics: _payloadObject(
        payload['healthMetrics'],
        LiveHealthMetrics.fromJson,
      ),
      exerciseTimings: _payloadObjects(
        payload['exerciseTimings'],
        ExerciseTiming.fromJson,
      ),
      pausedSeconds: _payloadInt(payload['pausedSeconds'], 0),
    );
  }

  WorkoutLog _mergeWatchCompletion({
    required WorkoutLog existing,
    required WorkoutLog incoming,
  }) {
    return existing.copyWith(
      completedAt: incoming.completedAt,
      notes: incoming.notes.isNotEmpty ? incoming.notes : existing.notes,
      sets: incoming.sets.isNotEmpty ? incoming.sets : existing.sets,
      healthWriteStatus: incoming.healthWriteStatus,
      healthMetrics: incoming.healthMetrics,
      exerciseTimings: incoming.exerciseTimings.isNotEmpty
          ? incoming.exerciseTimings
          : existing.exerciseTimings,
      clearPausedAt: true,
      pausedSeconds: incoming.pausedSeconds,
    );
  }

  WorkoutLog _mergeWatchProgress({
    required WorkoutLog existing,
    required WorkoutLog incoming,
  }) {
    return existing.copyWith(
      notes: incoming.notes.isNotEmpty ? incoming.notes : existing.notes,
      sets: incoming.sets.length >= existing.sets.length
          ? incoming.sets
          : existing.sets,
      healthWriteStatus: incoming.healthWriteStatus,
      healthMetrics: incoming.healthMetrics ?? existing.healthMetrics,
      exerciseTimings:
          incoming.exerciseTimings.length >= existing.exerciseTimings.length
          ? incoming.exerciseTimings
          : existing.exerciseTimings,
      pausedAt: incoming.pausedAt,
      clearPausedAt: incoming.pausedAt == null,
      pausedSeconds: incoming.pausedSeconds > existing.pausedSeconds
          ? incoming.pausedSeconds
          : existing.pausedSeconds,
    );
  }

  void _captureWorkoutMemory(WorkoutLog log) {
    final notes = log.notes.trim();
    final hasReadinessSignal = log.readiness <= 2 || log.soreness >= 4;
    final hasPerformanceSignal =
        log.sets.isNotEmpty && log.sets.any((set) => set.rpe >= 9);
    if (notes.isEmpty && !hasReadinessSignal && !hasPerformanceSignal) return;

    final category = hasReadinessSignal
        ? MemoryCategory.recovery
        : notes.toLowerCase().contains('form') ||
              notes.toLowerCase().contains('cue') ||
              notes.toLowerCase().contains('technik')
        ? MemoryCategory.form
        : MemoryCategory.training;
    final signalParts = [
      if (notes.isNotEmpty) notes,
      if (hasReadinessSignal)
        'Readiness ${log.readiness}/5, soreness ${log.soreness}/5.',
      if (hasPerformanceSignal)
        'At least one set reached RPE 9+, so future plans should manage fatigue.',
    ];

    _data = _data.copyWith(
      memories: [
        _autoMemory(
          category: category,
          title: '${log.title} signal',
          summary: signalParts.join(' '),
          markdown:
              'Captured from completed workout on ${dateKey(log.completedAt ?? log.startedAt)}.\n\n'
              'Total volume: ${log.totalVolume.toStringAsFixed(0)} kg across ${log.sets.length} sets.',
          source: 'auto_workout',
          confidence: notes.isEmpty ? 0.65 : 0.78,
        ),
        ..._data.memories,
      ],
    );
  }

  void _captureMealMemory(MealAnalysisResult result, String notes) {
    final parts = [
      if (notes.trim().isNotEmpty) notes.trim(),
      if (result.mealDescription.trim().isNotEmpty)
        result.mealDescription.trim(),
      if (result.rationale.trim().isNotEmpty) result.rationale.trim(),
      if (result.correctionNotes.trim().isNotEmpty)
        result.correctionNotes.trim(),
    ];
    if (parts.isEmpty) return;

    _data = _data.copyWith(
      memories: [
        _autoMemory(
          category: MemoryCategory.nutrition,
          title: 'Nutrition pattern',
          summary: parts.join(' '),
          markdown:
              '${result.calories} kcal, ${result.protein}g protein, '
              '${result.carbs}g carbs, ${result.fat}g fat. '
              'Bodyweight ${result.bodyWeightKg.toStringAsFixed(1)} kg.',
          source: 'auto_nutrition',
          confidence: result.confidence,
        ),
        ..._data.memories,
      ],
    );
  }

  MemoryEntry _autoMemory({
    required MemoryCategory category,
    required String title,
    required String summary,
    required String markdown,
    required String source,
    required double confidence,
  }) {
    final now = DateTime.now();
    return MemoryEntry(
      id: newId('memory'),
      createdAt: now,
      updatedAt: now,
      category: category,
      title: title,
      summary: summary,
      markdown: markdown,
      source: source,
      confidence: confidence.clamp(0, 1).toDouble(),
      active: true,
    );
  }

  Future<void> _persist(String status) async {
    _status = status;
    await _store.save(_data);
    notifyListeners();
  }
}

int _payloadInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

T? _payloadObject<T>(Object? value, T Function(Map<String, dynamic>) fromJson) {
  if (value is Map<String, dynamic>) return fromJson(value);
  if (value is Map) return fromJson(value.cast<String, dynamic>());
  return null;
}

List<T> _payloadObjects<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map<dynamic, dynamic>>()
      .map((item) => fromJson(item.cast<String, dynamic>()))
      .toList();
}
