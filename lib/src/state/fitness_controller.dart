import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';
import '../data/seed_data.dart';
import '../models/fitness_models.dart';
import '../services/coach_exchange_service.dart';
import '../services/health_sync_service.dart';
import '../services/media_capture_service.dart';

class FitnessController extends ChangeNotifier {
  FitnessController({
    LocalFitnessStore? store,
    HealthSyncService? health,
    MediaCaptureService? media,
  }) : _store = store ?? LocalFitnessStore(),
       _health = health ?? HealthSyncService(),
       _media = media ?? MediaCaptureService() {
    _coach = CoachExchangeService(_store);
  }

  final LocalFitnessStore _store;
  final HealthSyncService _health;
  final MediaCaptureService _media;
  late final CoachExchangeService _coach;

  FitnessData _data = createSeedFitnessData();
  bool _isLoading = true;
  bool _hasPendingCodexBlock = false;
  bool _hasPendingNutritionAnalysis = false;
  bool _isHealthTracking = false;
  LiveHealthMetrics? _liveHealthMetrics;
  Timer? _healthPoller;
  String _status = 'Loading local training data...';

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
  MealAnalysisRequest? get pendingMealRequest => _data.pendingMealRequest;
  MealAnalysisResult? get pendingMealResult => _data.pendingMealResult;
  FuelGuidance? get fuelGuidance => _data.fuelGuidance;

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
    _isLoading = false;
    _status = 'Local-first coaching data loaded';
    notifyListeners();
    await checkForCodexUpdates();
  }

  Future<void> createLocalBlock(TrainingStyle style) async {
    final block = createTemplateBlock(style);
    _data = _data.copyWith(
      blocks: [block, ..._data.blocks],
      activeBlockId: block.id,
      coachDecisions: [
        CoachDecision(
          id: newId('decision'),
          createdAt: DateTime.now(),
          title: '${style.label} block created',
          rationale:
              'This is a structured local 8-week block. Codex can replace it by writing a new training_block_plan.json to iCloud.',
          safetyFlags: const [],
          accepted: true,
        ),
        ..._data.coachDecisions,
      ],
    );
    await _persist('Created ${style.label} block');
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
    notifyListeners();
    await refreshLiveHealthMetrics();
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
    var completed = _data.logs[index].copyWith(
      completedAt: DateTime.now(),
      notes: notes,
      readiness: readiness,
      soreness: soreness,
      healthMetrics: finalHealthMetrics,
    );
    completed = await _syncCompletedWorkout(completed);

    final logs = [..._data.logs]..[index] = completed;
    _data = _data.copyWith(logs: logs);
    _captureWorkoutMemory(completed);
    await _persist('Workout stopped and saved');
    await _exportDayContext(notify: false);
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
    await _persist('Completed ${workout.title}');
    await _exportDayContext(notify: false);
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
    _healthPoller?.cancel();
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
