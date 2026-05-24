import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var store: WatchWorkoutStore

  var body: some View {
    NavigationStack {
      if store.isExerciseRunning {
        ActiveWorkoutView(workoutManager: store.workoutManager)
      } else if store.showSummaryOverlay, let summary = store.summary {
        WorkoutSummaryView(summary: summary)
      } else if let workout = store.workout {
        TodayWorkoutView(workout: workout)
      } else {
        EmptyWorkoutView()
      }
    }
  }
}

private struct EmptyWorkoutView: View {
  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "applewatch")
        .font(.title2)
      Text("Open iPhone app to sync today's workout")
        .font(.headline)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}

private struct TodayWorkoutView: View {
  @EnvironmentObject private var store: WatchWorkoutStore
  let workout: WatchPlannedWorkout

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        if store.completedPendingSync {
          Label("Result pending sync", systemImage: "icloud.and.arrow.up")
            .font(.caption)
            .foregroundStyle(.yellow)
        }
        if store.isWorkoutCompleted {
          completedCard
        } else if let exercise = store.currentExercise, store.hasRemainingExercises {
          Text("Next")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
          Text(exercise.name)
            .font(.headline)
          Text("\(exercise.sets) sets - \(exercise.reps) reps")
            .font(.caption)
            .foregroundStyle(.secondary)
          Button {
            store.startNextExercise()
          } label: {
            Label("Start", systemImage: "play.fill")
              .frame(maxWidth: .infinity)
          }
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
          Button {
            store.finish()
          } label: {
            Label("Finish", systemImage: "checkmark")
          }
          .font(.caption)
          .disabled(store.isActive == false)
        } else {
          Text(workout.title)
            .font(.headline)
          Text("No open exercises")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .navigationTitle("T4L")
  }

  private var completedCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
        Text("Done")
          .font(.caption)
          .foregroundStyle(.green)
      }
      Text(workout.title)
        .font(.headline)
        .lineLimit(3)
        .minimumScaleFactor(0.8)
        .fixedSize(horizontal: false, vertical: true)
      if let summary = store.summary {
        Text(durationText(summary.totalTime))
          .font(.title3.bold())
          .monospacedDigit()
      }
      Text("Waiting for next workout from iPhone")
        .font(.caption2)
        .foregroundStyle(.secondary)
      Button {
        store.openSummaryOverlay()
      } label: {
        Label("View summary", systemImage: "chart.bar.doc.horizontal")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.small)
      .buttonStyle(.bordered)
    }
  }
}

private struct ActiveWorkoutView: View {
  @EnvironmentObject private var store: WatchWorkoutStore
  @ObservedObject var workoutManager: WatchWorkoutManager

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(alignment: .leading, spacing: 10) {
        if let exercise = store.currentExercise {
          Text(exercise.name)
            .font(.headline)
            .lineLimit(2)
        }

        Text(elapsedText(at: context.date))
          .font(.system(size: 34, weight: .bold, design: .rounded))
          .monospacedDigit()

        HStack(spacing: 8) {
          metric("HR", value: heartRateText, color: .red)
          metric("KCAL", value: caloriesText, color: .orange)
        }

        HStack(spacing: 10) {
          Button {
            store.isPaused ? store.resume() : store.pause()
          } label: {
            Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
          }
          .tint(.yellow)

          Button(role: .destructive) {
            store.stopCurrentExercise()
          } label: {
            Image(systemName: "stop.fill")
          }
        }
      }
      .padding()
    }
    .navigationTitle("Workout")
  }

  private var heartRateText: String {
    guard let heartRate = workoutManager.currentHeartRateBpm else { return "--" }
    return "\(Int(heartRate.rounded()))"
  }

  private var caloriesText: String {
    guard let calories = workoutManager.activeEnergyKcal else { return "--" }
    return "\(Int(calories.rounded()))"
  }

  private func elapsedText(at date: Date) -> String {
    guard let startedAt = store.activeExerciseStartedAt else { return "00:00" }
    return durationText(date.timeIntervalSince(startedAt))
  }

  private func metric(_ label: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title3.bold())
        .monospacedDigit()
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private struct WorkoutSummaryView: View {
  @EnvironmentObject private var store: WatchWorkoutStore
  let summary: WatchWorkoutSummary

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 4) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
          Text("Done")
            .font(.caption)
            .foregroundStyle(.green)
        }
        Text(summary.title)
          .font(.headline)
          .lineLimit(3)
          .minimumScaleFactor(0.8)
          .fixedSize(horizontal: false, vertical: true)
        metric("TIME", durationText(summary.totalTime))
        metric("AVG HR", summary.averageHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--")
        metric("KCAL", summary.totalCalories.map { "\(Int($0.rounded()))" } ?? "--")
        Button {
          store.dismissSummaryOverlay()
        } label: {
          Text("Done")
            .frame(maxWidth: .infinity)
        }
        .controlSize(.small)
        .buttonStyle(.bordered)
        .padding(.top, 4)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal)
      .padding(.bottom)
    }
    .navigationTitle("Summary")
  }

  private func metric(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title3.bold())
        .monospacedDigit()
    }
  }
}

private func durationText(_ duration: TimeInterval) -> String {
  let totalSeconds = max(0, Int(duration.rounded()))
  let hours = totalSeconds / 3600
  let minutes = (totalSeconds % 3600) / 60
  let seconds = totalSeconds % 60
  if hours > 0 {
    return String(format: "%d:%02d:%02d", hours, minutes, seconds)
  }
  return String(format: "%02d:%02d", minutes, seconds)
}
