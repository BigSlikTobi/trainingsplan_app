import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/seed_data.dart';
import '../models/fitness_models.dart';
import '../services/coach_exchange_service.dart';
import '../services/health_sync_service.dart';
import '../services/local_bridge_service.dart';
import '../services/media_capture_service.dart';
import '../services/watch_sync_service.dart';

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
    _coach = CoachExchangeService(_store);
  }

  final LocalFitnessStore _store;
  final HealthSyncService _health;
  final MediaCaptureService _media;
  final LocalBridgeService _bridge;
  final WatchSyncService _watchSync;
  late final CoachExchangeService _coach;

  FitnessData _data = createEmptyFitnessData();
  bool _isLoading = true;
  bool _hasPendingCodexBlock = false;
  bool _hasPendingNutritionAnalysis = false;
  bool _isHealthTracking = false;
  LiveHealthMetrics? _liveHealthMetrics;
  Timer? _healthPoller;
  Timer? _uiTicker;
  String _status = 'Loading local training data...';
  WorkoutLog? _justCompletedLog;
  LocalBridgeConfig _bridgeConfig = const LocalBridgeConfig();
  StreamSubscription<Map<String, dynamic>>? _watchEvents;
  String? _activeWatchSessionWorkoutId;

  @visibleForTesting
  String? get debugActiveWatchSessionWorkoutId => _activeWatchSessionWorkoutId;

  FitnessData get data => _data;
  bool get isLoading => _isLoading;
  bool get hasPendingCodexBlock => _hasPendingCodexBlock;
  bool get hasPendingNutritionAnalysis => _hasPendingNutritionAnalysis;
  bool get isHealthTracking => _isHealthTracking;
  LiveHealthMetrics? get liveHealthMetrics => _liveHealthMetrics;
  String get status => _status;
  TrainingBlock? get activeBlock => _data.activeBlock;
  PlannedWorkout? get nextWorkout => _data.nextWorkout;
  bool get hasActiveWorkout => _data.hasActiveWorkout;
  WorkoutLog? get activeWorkoutLog => _activeWorkoutLog();
  WorkoutLog? get justCompletedLog => _justCompletedLog;
  MealAnalysisRequest? get pendingMealRequest => _data.pendingMealRequest;
  MealAnalysisResult? get pendingMealResult => _data.pendingMealResult;
  FuelGuidance? get fuelGuidance => _data.fuelGuidance;
  LocalBridgeConfig get bridgeConfig => _bridgeConfig;

  Future<void> syncWorkoutToWatch() async {
    // What the watch should show is derived from persisted state, not a
    // transient flag — otherwise any completion path that doesn't happen to
    // set _justCompletedLog (e.g. completeCurrentWorkout) ends up syncing
    // nextWorkout with no completedLog, which the watch reads as "fresh
    // workout, show Start". Priority:
    //   1) an active (uncompleted) log → sync that workout in active state
    //   2) any completed log → sync the most recently completed workout
    //      with its completedLog, so the watch shows the Done card
    //   3) fall back to nextWorkout for brand-new state
    PlannedWorkout? workout;
    WorkoutLog? activeLog;
    WorkoutLog? completedLog;

    final active = _activeWorkoutLog();
    if (active != null) {
      workout = _findWorkoutById(active.workoutId);
      activeLog = active;
    } else {
      final recent = _mostRecentCompletedLog();
      if (recent != null) {
        workout = _findWorkoutById(recent.workoutId);
        completedLog = recent;
      }
    }
    workout ??= nextWorkout;
    if (workout == null) {
      _status = 'No workout available for Apple Watch sync';
      notifyListeners();
      return;
    }
    // If we fell back to nextWorkout, fill completedLog from the data so a
    // pre-existing completion is still recognised.
    completedLog ??= _completedWorkoutLog(workout);

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
    _justCompletedLog = logs.firstWhere(
      (log) => log.workoutId == completion.workoutId && log.completedAt != null,
      orElse: () => completion,
    );
    _captureWorkoutMemory(_justCompletedLog!);
    await _persist('Imported Apple Watch workout');
    await _exportDayContext(notify: false);
    // Push the completion back to the watch so its UI flips from "Start"
    // to "Done" without waiting for the next user-triggered sync.
    unawaited(syncWorkoutToWatch());

    _markWatchCompletionHandled(payload);
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

  Future<String> exchangeDirectoryPath() async {
    final dir = await _store.getExchangeDirectory();
    _status = 'Exchange folder: ${dir.path}';
    notifyListeners();
    return dir.path;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    _data = await _store.load();
    _bridgeConfig = await _store.loadBridgeConfig();
    _isLoading = false;
    _status = 'Local-first coaching data loaded';
    try {
      _watchEvents ??= _watchSync.events.listen((event) {
        switch (event['type']) {
          case 'watchWorkoutCompleted':
            final payload = (event['payload'] as Map?)?.cast<String, dynamic>();
            if (payload != null) {
              unawaited(handleWatchWorkoutCompleted(payload));
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
    await checkForCodexUpdates();
  }

  Future<String> exportDailySnapshot() async {
    await _exportDayContext();
    final path = await _coach.exportDailySnapshot(_data);
    _status = 'Exported day_context.json and daily_snapshot.json to $path';
    notifyListeners();
    return path;
  }

  Future<void> importCodexBlockPlan() async {
    final block = await _coach.readTrainingBlockPlan();
    if (block == null) {
      _status = 'No training_block_plan.json found in exchange folder';
      notifyListeners();
      return;
    }
    _data = _data.copyWith(
      blocks: [block, ..._data.blocks],
      activeBlockId: block.id,
      coachDecisions: [
        CoachDecision(
          id: newId('decision'),
          createdAt: DateTime.now(),
          title: 'Imported Codex block',
          rationale:
              'Codex block import passed schema validation and is now the active plan.',
          safetyFlags: const [],
          accepted: true,
        ),
        ..._data.coachDecisions,
      ],
    );
    await _coach.clearTrainingBlockPlan();
    _hasPendingCodexBlock = false;
    await _persist('Imported Codex block plan');
  }

  Future<void> checkForCodexBlockPlan() async {
    final hasPlan = await _coach.hasTrainingBlockPlan();
    if (_hasPendingCodexBlock == hasPlan) return;
    _hasPendingCodexBlock = hasPlan;
    if (hasPlan) {
      _status = 'New Codex training block available';
    }
    notifyListeners();
  }

  Future<void> checkForCodexUpdates() async {
    await checkForCodexBlockPlan();
    await checkForNutritionAnalysisResult();
    await importFuelGuidance();
    await importExchangeMemoryWiki();
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
    } on Object catch (error) {
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
      await _exportDayContext(notify: false);
      await _coach.exportDailySnapshot(_data);
      final dayContext = await _store.readExchangeJson('day_context.json');
      final dailySnapshot = await _store.readExchangeJson(
        'daily_snapshot.json',
      );
      await _bridge.uploadAppSnapshot(_bridgeConfig, {
        'schema': 't4l_app_snapshot.v1',
        'createdAt': DateTime.now().toIso8601String(),
        'fitnessData': _data.toJson(),
        'dayContext': ?dayContext,
        'dailySnapshot': ?dailySnapshot,
      });
      _bridgeConfig = _bridgeConfig.copyWith(lastSyncAt: DateTime.now());
      await _store.saveBridgeConfig(_bridgeConfig);
      _status =
          'Migrated local training snapshot to self-hosted server. Phone data unchanged.';
    } on Object catch (error) {
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
      await _exportDayContext(notify: false);
      await _coach.exportDailySnapshot(_data);
      await _bridge.uploadProfile(_bridgeConfig, {
        'schema': 'athlete_profile.v1',
        'createdAt': DateTime.now().toIso8601String(),
        'profile': _data.profile.toJson(),
      });
      final uploaded = <String>['athlete_profile.json'];
      final dayContext = await _store.readExchangeJson('day_context.json');
      if (dayContext != null) {
        await _bridge.uploadDayContext(_bridgeConfig, dayContext);
        uploaded.add('day_context.json');
      }
      final dailySnapshot = await _store.readExchangeJson(
        'daily_snapshot.json',
      );
      if (dailySnapshot != null) {
        await _bridge.uploadDailySnapshot(_bridgeConfig, dailySnapshot);
        uploaded.add('daily_snapshot.json');
      }
      for (final fileName in const [
        'training_block_request.json',
        'nutrition_analysis_request.json',
      ]) {
        final payload = await _store.readExchangeJson(fileName);
        if (payload == null) continue;
        await _bridge.uploadJson(_bridgeConfig, fileName, payload);
        uploaded.add(fileName);
      }
      final exchangeDir = await _store.getExchangeDirectory();
      final imagesDir = Directory('${exchangeDir.path}/meal_images');
      if (imagesDir.existsSync()) {
        for (final entity in imagesDir.listSync()) {
          if (entity is! File) continue;
          final name = entity.uri.pathSegments.last;
          await _bridge.uploadBytes(
            _bridgeConfig,
            'meal_images/$name',
            await entity.readAsBytes(),
          );
          uploaded.add('meal_images/$name');
        }
      }
      _bridgeConfig = _bridgeConfig.copyWith(lastSyncAt: DateTime.now());
      await _store.saveBridgeConfig(_bridgeConfig);
      _status = 'Pushed ${uploaded.join(', ')} to self-hosted server';
    } on Object catch (error) {
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
    final downloaded = <String>[];
    try {
      const resultFiles = {
        'training_block_plan': 'training_block_plan.json',
        'next_day_plan': 'next_day_plan.json',
        'nutrition_analysis_result': 'nutrition_analysis_result.json',
        'fuel_guidance': 'fuel_guidance.json',
      };
      final pendingKinds = await _bridge.pendingResultKinds(_bridgeConfig);
      for (final kind in pendingKinds) {
        final fileName = resultFiles[kind];
        if (fileName == null) continue;
        final payload = await _bridge.downloadResult(_bridgeConfig, kind);
        if (payload == null) continue;
        await _store.writeExchangeJson(fileName, payload);
        await _bridge.markResultConsumed(_bridgeConfig, kind);
        downloaded.add(fileName);
      }
      await checkForCodexUpdates();
      _bridgeConfig = _bridgeConfig.copyWith(lastSyncAt: DateTime.now());
      await _store.saveBridgeConfig(_bridgeConfig);
      _status = downloaded.isEmpty
          ? 'No self-hosted server results found'
          : 'Pulled ${downloaded.join(', ')} from self-hosted server';
    } on Object catch (error) {
      _status = 'Server result check failed: $error';
    }
    notifyListeners();
  }

  Future<void> importExchangeMemoryWiki() async {
    try {
      final incoming = await _coach.readExchangeMemoryWikiEntries();
      if (incoming.isEmpty) return;
      final existingKeys = _data.memories.map(_memoryImportKey).toSet();
      final imported = <MemoryEntry>[];
      for (final memory in incoming) {
        final key = _memoryImportKey(memory);
        if (existingKeys.add(key)) {
          imported.add(memory);
        }
      }
      if (imported.isEmpty) return;
      _data = _data.copyWith(memories: [...imported, ..._data.memories]);
      await _persist(
        'Imported ${imported.length} coach memory '
        '${imported.length == 1 ? 'entry' : 'entries'}',
      );
    } on Object catch (error) {
      _status = 'Memory wiki import failed: $error';
      notifyListeners();
    }
  }

  Future<void> importFuelGuidance() async {
    final hasFuel = await _coach.hasFuelGuidance();
    if (!hasFuel) return;
    try {
      final guidance = await _coach.readFuelGuidance();
      if (guidance == null) return;
      _data = _data.copyWith(fuelGuidance: guidance);
      await _coach.clearFuelGuidance();
      await _persist('Imported fuel guidance from coach');
    } on Object catch (error) {
      _status = 'Fuel guidance import failed: $error';
      notifyListeners();
    }
  }

  Future<void> importNextDayPlan() async {
    final workout = await _coach.readNextDayPlan();
    final block = activeBlock;
    if (workout == null || block == null) {
      _status = 'No next_day_plan.json found or no active block exists';
      notifyListeners();
      return;
    }
    final updatedBlock = block.copyWith(workouts: [workout, ...block.workouts]);
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
    await _persist('Imported next-day plan from Codex');
  }

  Future<void> logSet(
    ExercisePrescription exercise,
    double weight,
    int reps,
    double rpe,
  ) async {
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
  }

  Future<void> startCurrentWorkout() async {
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
  }

  Future<void> pauseExerciseTimer(String exerciseId) async {
    final mutated = _mutateActiveExerciseTiming(
      exerciseId,
      (t) => t.isRunning ? t.copyWith(pausedAt: DateTime.now()) : null,
    );
    if (mutated != null) {
      await _persist('Paused timer: ${mutated.exerciseName}');
    }
  }

  Future<void> resumeExerciseTimer(String exerciseId) async {
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
    }
  }

  Future<void> stopExerciseTimer(
    String exerciseId, {
    bool autoCloseWorkout = true,
  }) async {
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
    if (autoCloseWorkout) await _maybeAutoCloseWorkout();
  }

  Future<void> tryAutoCloseWorkout() => _maybeAutoCloseWorkout();

  Future<void> pauseCurrentWorkout() async {
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

  ExerciseTiming? _timingFor(String exerciseId) {
    final log = _activeWorkoutLog();
    if (log == null) return null;
    final i = log.exerciseTimings.indexWhere((t) => t.exerciseId == exerciseId);
    return i < 0 ? null : log.exerciseTimings[i];
  }

  bool isExerciseRunning(String exerciseId) =>
      _timingFor(exerciseId)?.isRunning ?? false;
  bool isExercisePaused(String exerciseId) =>
      _timingFor(exerciseId)?.isPaused ?? false;
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
    if (workout == null) return;
    final index = _data.logs.indexWhere(
      (log) => log.workoutId == workout.id && log.completedAt == null,
    );
    if (index < 0) {
      _status = 'Log at least one set before completing the workout';
      notifyListeners();
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

  Future<void> updateProfile(AthleteProfile profile) async {
    _data = _data.copyWith(profile: profile);
    await _persist('Profile updated for Codex nutrition context');
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
    await _exportDayContext(notify: false);
    final (request, path) = await _coach.exportNutritionAnalysisRequest(
      data: _data,
      description: description,
      imagePath: imagePath,
    );
    _data = _data.copyWith(
      pendingMealRequest: request,
      pendingMealResult: null,
    );
    _hasPendingNutritionAnalysis = false;
    await _store.save(_data);
    _status = 'Exported nutrition_analysis_request.json to $path';
    notifyListeners();
  }

  Future<void> checkForNutritionAnalysisResult() async {
    final hasResult = await _coach.hasNutritionAnalysisResult();
    if (!hasResult) {
      if (_hasPendingNutritionAnalysis) {
        _hasPendingNutritionAnalysis = false;
        notifyListeners();
      }
      return;
    }
    if (_data.pendingMealResult != null && _hasPendingNutritionAnalysis) {
      return;
    }
    try {
      final result = await _coach.readNutritionAnalysisResult();
      if (result == null) return;
      _data = _data.copyWith(pendingMealResult: result);
      _hasPendingNutritionAnalysis = true;
      _status = 'Codex nutrition analysis ready for review';
      await _store.save(_data);
    } on Object catch (error) {
      _status = 'Nutrition analysis import failed: $error';
    }
    notifyListeners();
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
    await _coach.clearNutritionAnalysisResult();
    await _coach.clearNutritionAnalysisRequest();
    _hasPendingNutritionAnalysis = false;
    _captureMealMemory(accepted, notes);
    await saveNutrition(accepted.toNutritionLog(notes: notes));
    _status = 'Accepted Codex nutrition analysis and saved calories';
    notifyListeners();
  }

  Future<void> discardMealAnalysis() async {
    _data = _data.copyWith(pendingMealRequest: null, pendingMealResult: null);
    _hasPendingNutritionAnalysis = false;
    await _coach.clearNutritionAnalysisResult();
    await _coach.clearNutritionAnalysisRequest();
    await _persist('Discarded Codex nutrition analysis');
  }

  Future<void> connectHealth() async {
    try {
      _status = await _health.requestPermissions();
    } on Object catch (error) {
      _status = 'HealthKit setup failed: $error';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _watchEvents?.cancel();
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

  WorkoutLog? _completedWorkoutLog(PlannedWorkout workout) {
    WorkoutLog? latest;
    for (final log in _data.logs) {
      if (log.workoutId != workout.id || log.completedAt == null) continue;
      if (latest == null || log.completedAt!.isAfter(latest.completedAt!)) {
        latest = log;
      }
    }
    return latest;
  }

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

  Future<String> _exportDayContext({bool notify = true}) async {
    final now = DateTime.now();
    final activityReport = await _health.readDayActivityReport(now);
    final path = await _coach.exportDayContext(
      data: _data,
      activityReport: activityReport,
      day: now,
    );
    if (notify) {
      _status = 'Exported day_context.json to $path';
      notifyListeners();
    }
    return path;
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

String _memoryImportKey(MemoryEntry memory) {
  return [
    memory.category.name,
    memory.source.trim().toLowerCase(),
    memory.title.trim().toLowerCase(),
    memory.summary.trim().toLowerCase(),
  ].join('\n');
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
      .whereType<Map>()
      .map((item) => fromJson(item.cast<String, dynamic>()))
      .toList();
}
