import Foundation

struct WatchWorkoutEnvelope: Codable {
  let schemaVersion: Int
  let sentAt: String
  let workout: WatchPlannedWorkout
  let activeLog: WatchActiveLog?
}

struct WatchActiveLog: Codable {
  let id: String
  let workoutId: String
  let startedAt: String
  let pausedAt: String?
  let pausedSeconds: Int?
}

struct WatchPlannedWorkout: Codable, Identifiable {
  let id: String
  let week: Int
  let day: Int
  let title: String
  let focus: String
  let rationale: String
  let exercises: [WatchExercise]
  let conditioning: String
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
  let exerciseId: String
  let exerciseName: String
  let startedAt: String
  let completedAt: String
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
