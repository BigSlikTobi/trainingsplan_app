import 'package:health/health.dart';

import '../models/fitness_models.dart';

class HealthWorkoutMatch {
  const HealthWorkoutMatch({required this.status, required this.metrics});

  final String status;
  final LiveHealthMetrics metrics;
}

class HealthSyncService {
  HealthSyncService({Health? health}) : _health = health ?? Health();

  final Health _health;

  Future<String> requestPermissions() async {
    await _health.configure();
    final types = [
      HealthDataType.WORKOUT,
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.WEIGHT,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.DIETARY_ENERGY_CONSUMED,
      HealthDataType.DIETARY_PROTEIN_CONSUMED,
      HealthDataType.DIETARY_CARBS_CONSUMED,
      HealthDataType.DIETARY_FATS_CONSUMED,
    ];
    final permissions = [
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE,
      HealthDataAccess.READ_WRITE,
    ];
    final granted = await _health.requestAuthorization(
      types,
      permissions: permissions,
    );
    return granted ? 'HealthKit connected' : 'HealthKit permission denied';
  }

  Future<bool> requestLiveWorkoutPermissions() async {
    await _health.configure();
    const types = [
      HealthDataType.HEART_RATE,
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BLOOD_OXYGEN,
    ];
    return _health.requestAuthorization(
      types,
      permissions: types.map((_) => HealthDataAccess.READ).toList(),
    );
  }

  Future<LiveHealthMetrics> readLiveWorkoutMetrics(DateTime startedAt) async {
    await _health.configure();
    final now = DateTime.now();
    final points = await _health.getHealthDataFromTypes(
      types: const [
        HealthDataType.HEART_RATE,
        HealthDataType.STEPS,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BLOOD_OXYGEN,
      ],
      startTime: startedAt,
      endTime: now,
    );

    double? heartRate;
    double? bloodOxygen;
    var steps = 0;
    var activeEnergy = 0.0;
    DateTime? latestHeartRateAt;
    DateTime? latestBloodOxygenAt;

    for (final point in points) {
      final value = _numericValue(point.value);
      if (value == null) continue;

      switch (point.type) {
        case HealthDataType.HEART_RATE:
          if (latestHeartRateAt == null ||
              point.dateTo.isAfter(latestHeartRateAt)) {
            latestHeartRateAt = point.dateTo;
            heartRate = value.toDouble();
          }
        case HealthDataType.BLOOD_OXYGEN:
          if (latestBloodOxygenAt == null ||
              point.dateTo.isAfter(latestBloodOxygenAt)) {
            latestBloodOxygenAt = point.dateTo;
            bloodOxygen = value.toDouble();
          }
        case HealthDataType.STEPS:
          steps += value.round();
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          activeEnergy += value.toDouble();
        default:
          break;
      }
    }

    return LiveHealthMetrics(
      updatedAt: now,
      sampleCount: points.length,
      heartRateBpm: heartRate,
      steps: steps == 0 ? null : steps,
      activeEnergyKcal: activeEnergy == 0 ? null : activeEnergy,
      bloodOxygenPercent: bloodOxygen,
    );
  }

  Future<HealthWorkoutMatch?> readCompletedWorkoutMatch(WorkoutLog log) async {
    if (log.completedAt == null) return null;
    await _health.configure();
    const types = [
      HealthDataType.WORKOUT,
      HealthDataType.HEART_RATE,
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.BLOOD_OXYGEN,
    ];
    final granted = await _health.requestAuthorization(
      types,
      permissions: types.map((_) => HealthDataAccess.READ).toList(),
    );
    if (!granted) return null;

    final queryStart = log.startedAt.subtract(const Duration(minutes: 20));
    final queryEnd = log.completedAt!.add(const Duration(minutes: 20));
    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: queryStart,
      endTime: queryEnd,
    );
    final workouts = points.where(
      (point) => point.type == HealthDataType.WORKOUT,
    );
    HealthDataPoint? bestWorkout;
    var bestOverlap = Duration.zero;
    for (final workout in workouts) {
      final overlap = _overlap(
        log.startedAt,
        log.completedAt!,
        workout.dateFrom,
        workout.dateTo,
      );
      if (overlap > bestOverlap) {
        bestOverlap = overlap;
        bestWorkout = workout;
      }
    }
    if (bestWorkout == null || bestOverlap.inMinutes < 5) return null;

    final workoutValue = bestWorkout.value is WorkoutHealthValue
        ? bestWorkout.value as WorkoutHealthValue
        : null;
    final summary = bestWorkout.workoutSummary;
    final workoutStart = bestWorkout.dateFrom;
    final workoutEnd = bestWorkout.dateTo;

    double? heartRateTotal;
    var heartRateCount = 0;
    double? bloodOxygen;
    DateTime? latestBloodOxygenAt;
    var steps = workoutValue?.totalSteps ?? summary?.totalSteps.round() ?? 0;
    var activeEnergy =
        (workoutValue?.totalEnergyBurned ?? summary?.totalEnergyBurned)
            ?.toDouble() ??
        0.0;
    var sampleCount = 0;

    for (final point in points) {
      if (point.dateTo.isBefore(workoutStart) ||
          point.dateFrom.isAfter(workoutEnd)) {
        continue;
      }
      final value = _numericValue(point.value);
      if (value == null) continue;
      sampleCount += 1;
      switch (point.type) {
        case HealthDataType.HEART_RATE:
          heartRateTotal = (heartRateTotal ?? 0) + value.toDouble();
          heartRateCount += 1;
        case HealthDataType.BLOOD_OXYGEN:
          if (latestBloodOxygenAt == null ||
              point.dateTo.isAfter(latestBloodOxygenAt)) {
            latestBloodOxygenAt = point.dateTo;
            bloodOxygen = value.toDouble();
          }
        case HealthDataType.STEPS:
          if (workoutValue?.totalSteps == null && summary == null) {
            steps += value.round();
          }
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          if (workoutValue?.totalEnergyBurned == null && summary == null) {
            activeEnergy += value.toDouble();
          }
        default:
          break;
      }
    }

    final workoutType = workoutValue?.workoutActivityType.name;
    final metrics = LiveHealthMetrics(
      updatedAt: DateTime.now(),
      sampleCount: sampleCount,
      heartRateBpm: heartRateCount == 0
          ? null
          : heartRateTotal! / heartRateCount,
      steps: steps == 0 ? null : steps,
      activeEnergyKcal: activeEnergy == 0 ? null : activeEnergy,
      bloodOxygenPercent: bloodOxygen,
    );
    return HealthWorkoutMatch(
      status: workoutType == null
          ? 'matched_apple_health_workout'
          : 'matched_apple_health_workout:$workoutType',
      metrics: metrics,
    );
  }

  Future<String> writeWorkout(WorkoutLog log) async {
    if (log.completedAt == null) return 'workout_not_completed';
    await _health.configure();
    final granted = await _health.requestAuthorization(
      [HealthDataType.WORKOUT],
      permissions: [HealthDataAccess.READ_WRITE],
    );
    if (!granted) return 'health_permission_denied';
    final success = await _health.writeWorkoutData(
      activityType: HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING,
      start: log.startedAt,
      end: log.completedAt!,
      title: log.title,
      recordingMethod: RecordingMethod.manual,
    );
    return success ? 'written_to_apple_health' : 'health_write_failed';
  }

  Future<DayActivityReport> readDayActivityReport(DateTime day) async {
    final windowStart = DateTime(day.year, day.month, day.day);
    final windowEnd = windowStart.add(const Duration(days: 1));
    const types = [
      HealthDataType.WORKOUT,
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.EXERCISE_TIME,
      HealthDataType.APPLE_MOVE_TIME,
      HealthDataType.DISTANCE_WALKING_RUNNING,
      HealthDataType.DISTANCE_CYCLING,
      HealthDataType.FLIGHTS_CLIMBED,
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      HealthDataType.BLOOD_OXYGEN,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.WEIGHT,
      HealthDataType.DIETARY_ENERGY_CONSUMED,
      HealthDataType.DIETARY_PROTEIN_CONSUMED,
      HealthDataType.DIETARY_CARBS_CONSUMED,
      HealthDataType.DIETARY_FATS_CONSUMED,
    ];

    try {
      await _health.configure();
      final granted = await _health.requestAuthorization(
        types,
        permissions: types.map((_) => HealthDataAccess.READ).toList(),
      );
      if (!granted) {
        return DayActivityReport(
          summary: DayActivitySummary(
            readStatus: 'health_permission_denied',
            missingPermissions: types.map((item) => item.name).toList(),
            sampleCount: 0,
          ),
          sessions: const [],
        );
      }

      final points = await _health.getHealthDataFromTypes(
        types: types,
        startTime: windowStart,
        endTime: windowEnd,
      );
      return _buildDayActivityReport(points, readStatus: 'ok');
    } on Object catch (error) {
      return DayActivityReport(
        summary: DayActivitySummary(
          readStatus: 'health_read_failed: $error',
          missingPermissions: const [],
          sampleCount: 0,
        ),
        sessions: const [],
      );
    }
  }

  Future<String> writeNutrition(NutritionLog log) async {
    await _health.configure();
    final types = [
      HealthDataType.DIETARY_ENERGY_CONSUMED,
      HealthDataType.DIETARY_PROTEIN_CONSUMED,
      HealthDataType.DIETARY_CARBS_CONSUMED,
      HealthDataType.DIETARY_FATS_CONSUMED,
      HealthDataType.WEIGHT,
    ];
    final granted = await _health.requestAuthorization(
      types,
      permissions: types.map((_) => HealthDataAccess.READ_WRITE).toList(),
    );
    if (!granted) return 'health_permission_denied';

    final start = DateTime(log.date.year, log.date.month, log.date.day, 12);
    final end = start.add(const Duration(minutes: 1));
    var success = true;
    success &= await _health.writeHealthData(
      value: log.calories.toDouble(),
      type: HealthDataType.DIETARY_ENERGY_CONSUMED,
      startTime: start,
      endTime: end,
      recordingMethod: RecordingMethod.manual,
    );
    success &= await _health.writeHealthData(
      value: log.protein.toDouble(),
      type: HealthDataType.DIETARY_PROTEIN_CONSUMED,
      startTime: start,
      endTime: end,
      recordingMethod: RecordingMethod.manual,
    );
    success &= await _health.writeHealthData(
      value: log.carbs.toDouble(),
      type: HealthDataType.DIETARY_CARBS_CONSUMED,
      startTime: start,
      endTime: end,
      recordingMethod: RecordingMethod.manual,
    );
    success &= await _health.writeHealthData(
      value: log.fat.toDouble(),
      type: HealthDataType.DIETARY_FATS_CONSUMED,
      startTime: start,
      endTime: end,
      recordingMethod: RecordingMethod.manual,
    );
    if (log.bodyWeightKg > 0) {
      success &= await _health.writeHealthData(
        value: log.bodyWeightKg,
        type: HealthDataType.WEIGHT,
        startTime: start,
        endTime: end,
        recordingMethod: RecordingMethod.manual,
      );
    }
    return success
        ? 'nutrition_written_to_apple_health'
        : 'nutrition_write_failed';
  }

  num? _numericValue(HealthValue value) {
    if (value is NumericHealthValue) return value.numericValue;
    return null;
  }

  DayActivityReport _buildDayActivityReport(
    List<HealthDataPoint> points, {
    required String readStatus,
  }) {
    var steps = 0;
    var activeEnergy = 0.0;
    var exerciseMinutes = 0.0;
    var appleMoveMinutes = 0.0;
    var walkingRunningDistance = 0.0;
    var cyclingDistance = 0.0;
    var flightsClimbed = 0;
    double? restingHeartRate;
    DateTime? latestRestingHeartRateAt;
    double? heartRateTotal;
    var heartRateCount = 0;
    double? minHeartRate;
    double? maxHeartRate;
    double? bloodOxygen;
    DateTime? latestBloodOxygenAt;
    final sleepMinutesByStage = <String, double>{};
    double? weight;
    DateTime? latestWeightAt;
    var dietaryEnergy = 0.0;
    var dietaryProtein = 0.0;
    var dietaryCarbs = 0.0;
    var dietaryFat = 0.0;
    final sessions = <DayActivitySession>[];

    for (final point in points) {
      if (point.type == HealthDataType.WORKOUT) {
        sessions.add(_activitySessionFromPoint(point, points));
        continue;
      }

      final value = _numericValue(point.value);
      if (value == null) continue;
      final numeric = value.toDouble();

      switch (point.type) {
        case HealthDataType.STEPS:
          steps += value.round();
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          activeEnergy += numeric;
        case HealthDataType.EXERCISE_TIME:
          exerciseMinutes += numeric;
        case HealthDataType.APPLE_MOVE_TIME:
          appleMoveMinutes += numeric / 60;
        case HealthDataType.DISTANCE_WALKING_RUNNING:
          walkingRunningDistance += numeric;
        case HealthDataType.DISTANCE_CYCLING:
          cyclingDistance += numeric;
        case HealthDataType.FLIGHTS_CLIMBED:
          flightsClimbed += value.round();
        case HealthDataType.RESTING_HEART_RATE:
          if (latestRestingHeartRateAt == null ||
              point.dateTo.isAfter(latestRestingHeartRateAt)) {
            latestRestingHeartRateAt = point.dateTo;
            restingHeartRate = numeric;
          }
        case HealthDataType.HEART_RATE:
          heartRateTotal = (heartRateTotal ?? 0) + numeric;
          heartRateCount += 1;
          minHeartRate = minHeartRate == null || numeric < minHeartRate
              ? numeric
              : minHeartRate;
          maxHeartRate = maxHeartRate == null || numeric > maxHeartRate
              ? numeric
              : maxHeartRate;
        case HealthDataType.BLOOD_OXYGEN:
          if (latestBloodOxygenAt == null ||
              point.dateTo.isAfter(latestBloodOxygenAt)) {
            latestBloodOxygenAt = point.dateTo;
            bloodOxygen = numeric;
          }
        case HealthDataType.SLEEP_ASLEEP:
        case HealthDataType.SLEEP_AWAKE:
        case HealthDataType.SLEEP_DEEP:
        case HealthDataType.SLEEP_IN_BED:
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_REM:
          sleepMinutesByStage.update(
            point.type.name,
            (current) => current + numeric,
            ifAbsent: () => numeric,
          );
        case HealthDataType.WEIGHT:
          if (latestWeightAt == null || point.dateTo.isAfter(latestWeightAt)) {
            latestWeightAt = point.dateTo;
            weight = numeric;
          }
        case HealthDataType.DIETARY_ENERGY_CONSUMED:
          dietaryEnergy += numeric;
        case HealthDataType.DIETARY_PROTEIN_CONSUMED:
          dietaryProtein += numeric;
        case HealthDataType.DIETARY_CARBS_CONSUMED:
          dietaryCarbs += numeric;
        case HealthDataType.DIETARY_FATS_CONSUMED:
          dietaryFat += numeric;
        default:
          break;
      }
    }

    sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return DayActivityReport(
      summary: DayActivitySummary(
        readStatus: readStatus,
        missingPermissions: const [],
        sampleCount: points.length,
        steps: steps == 0 ? null : steps,
        activeEnergyKcal: activeEnergy == 0 ? null : activeEnergy,
        exerciseMinutes: exerciseMinutes == 0 ? null : exerciseMinutes,
        appleMoveMinutes: appleMoveMinutes == 0 ? null : appleMoveMinutes,
        walkingRunningDistanceMeters: walkingRunningDistance == 0
            ? null
            : walkingRunningDistance,
        cyclingDistanceMeters: cyclingDistance == 0 ? null : cyclingDistance,
        flightsClimbed: flightsClimbed == 0 ? null : flightsClimbed,
        restingHeartRateBpm: restingHeartRate,
        averageHeartRateBpm: heartRateCount == 0
            ? null
            : heartRateTotal! / heartRateCount,
        minHeartRateBpm: minHeartRate,
        maxHeartRateBpm: maxHeartRate,
        bloodOxygenPercent: bloodOxygen,
        sleepMinutesByStage: sleepMinutesByStage,
        weightKg: weight,
        dietaryEnergyKcal: dietaryEnergy == 0 ? null : dietaryEnergy,
        dietaryProteinGrams: dietaryProtein == 0 ? null : dietaryProtein,
        dietaryCarbsGrams: dietaryCarbs == 0 ? null : dietaryCarbs,
        dietaryFatGrams: dietaryFat == 0 ? null : dietaryFat,
      ),
      sessions: sessions,
    );
  }

  DayActivitySession _activitySessionFromPoint(
    HealthDataPoint workout,
    List<HealthDataPoint> points,
  ) {
    final workoutValue = workout.value is WorkoutHealthValue
        ? workout.value as WorkoutHealthValue
        : null;
    final summary = workout.workoutSummary;
    final steps = workoutValue?.totalSteps ?? summary?.totalSteps.round();
    final activeEnergy =
        (workoutValue?.totalEnergyBurned ?? summary?.totalEnergyBurned)
            ?.toDouble();
    final distance = (workoutValue?.totalDistance ?? summary?.totalDistance)
        ?.toDouble();
    double? heartRateTotal;
    var heartRateCount = 0;
    for (final point in points) {
      if (point.type != HealthDataType.HEART_RATE) continue;
      if (point.dateTo.isBefore(workout.dateFrom) ||
          point.dateFrom.isAfter(workout.dateTo)) {
        continue;
      }
      final value = _numericValue(point.value);
      if (value == null) continue;
      heartRateTotal = (heartRateTotal ?? 0) + value.toDouble();
      heartRateCount += 1;
    }

    return DayActivitySession(
      id: workout.uuid,
      activityType: workoutValue?.workoutActivityType.name ?? 'WORKOUT',
      startedAt: workout.dateFrom,
      endedAt: workout.dateTo,
      sourceName: workout.sourceName,
      durationMinutes:
          workout.dateTo.difference(workout.dateFrom).inSeconds / 60,
      distanceMeters: distance == 0 ? null : distance,
      activeEnergyKcal: activeEnergy == 0 ? null : activeEnergy,
      steps: steps == 0 ? null : steps,
      averageHeartRateBpm: heartRateCount == 0
          ? null
          : heartRateTotal! / heartRateCount,
    );
  }

  Duration _overlap(
    DateTime aStart,
    DateTime aEnd,
    DateTime bStart,
    DateTime bEnd,
  ) {
    final start = aStart.isAfter(bStart) ? aStart : bStart;
    final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    if (!end.isAfter(start)) return Duration.zero;
    return end.difference(start);
  }
}
