import Foundation

struct WatchWorkoutEnvelope: Codable {
  let schemaVersion: Int
  let sentAt: String
  let workout: WatchPlannedWorkout
  let activeLog: WatchActiveLog?
  let completedLog: WatchCompletedLog?
}

struct WatchActiveLog: Codable {
  let id: String
  let workoutId: String
  let startedAt: String
  let pausedAt: String?
  let pausedSeconds: Int?
  let sets: [WatchLoggedSet]?
  let exerciseTimings: [WatchExerciseTiming]?
}

struct WatchCompletedLog: Codable {
  let id: String
  let workoutId: String
  let title: String
  let startedAt: String
  let completedAt: String?
  let totalDurationSeconds: Int?
  let pausedSeconds: Int?
  let healthMetrics: WatchHealthMetrics?
}

struct WatchPlannedWorkout: Codable, Identifiable {
  let id: String
  let week: Int
  let day: Int
  let title: String
  let focus: String
  let rationale: String
  let exercises: [WatchExercise]
  let executionSteps: [WatchExecutionStep]?
  let conditioning: String

  var orderedSteps: [WatchExecutionStep] {
    if let executionSteps, !executionSteps.isEmpty { return executionSteps }
    return exercises.enumerated().map { index, exercise in
      WatchExecutionStep(
        stepId: exercise.exerciseId,
        stepIndex: index,
        totalSteps: exercises.count,
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.name,
        restSeconds: exercise.restSeconds,
        groupId: nil,
        groupType: nil,
        groupTitle: nil,
        round: nil,
        roundCount: nil,
        exercise: exercise
      )
    }
  }
}

struct WatchExercise: Codable, Identifiable {
  var id: String { exerciseId }

  let exerciseId: String
  let name: String
  let sets: Int
  let reps: String
  let targetLoad: String
  let targetRpe: Double
  let restSeconds: Int
  let coachCue: String
}

struct WatchExecutionStep: Codable, Identifiable {
  var id: String { stepId }

  let stepId: String
  let stepIndex: Int
  let totalSteps: Int
  let exerciseId: String
  let exerciseName: String
  let restSeconds: Int
  let groupId: String?
  let groupType: String?
  let groupTitle: String?
  let round: Int?
  let roundCount: Int?
  let exercise: WatchExercise

  var isGrouped: Bool { groupId != nil }

  var contextLabel: String? {
    var parts: [String] = []
    if let groupTitle, !groupTitle.isEmpty { parts.append(groupTitle) }
    if let round, let roundCount { parts.append("Runde \(round)/\(roundCount)") }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }
}

struct WatchLoggedSet: Codable, Identifiable {
  var id: String { "\(exerciseId)-\(setNumber)" }

  let exerciseId: String
  let exerciseName: String
  let setNumber: Int
  let weightKg: Double
  let reps: Int
  let rpe: Double
}

struct WatchExerciseTiming: Codable {
  let stepId: String?
  let exerciseId: String
  let exerciseName: String
  let startedAt: String
  let completedAt: String?
  let pausedAt: String?
  let pausedSeconds: Int
}

struct WatchHealthMetrics: Codable {
  let updatedAt: String
  let sampleCount: Int
  let heartRateBpm: Double?
  let activeEnergyKcal: Double?
}

struct WatchCompletionPayload: Codable {
  let schemaVersion: Int
  let completionId: String
  let workoutId: String
  let title: String
  let startedAt: String
  let completedAt: String
  let pausedSeconds: Int
  let sets: [WatchLoggedSet]
  let exerciseTimings: [WatchExerciseTiming]
  let healthMetrics: WatchHealthMetrics?
  let healthWriteStatus: String
}

struct WatchProgressPayload: Codable {
  let schemaVersion: Int
  let revision: Int
  let sentAt: String
  let workoutId: String
  let title: String
  let startedAt: String
  let pausedAt: String?
  let pausedSeconds: Int
  let activeExerciseId: String?
  let exerciseIndex: Int
  let sets: [WatchLoggedSet]
  let exerciseTimings: [WatchExerciseTiming]
  let healthMetrics: WatchHealthMetrics?
  let healthWriteStatus: String
}

struct WatchWorkoutSummary {
  let title: String
  let totalTime: TimeInterval
  let averageHeartRate: Double?
  let totalCalories: Double?
  let completedAt: Date
}
