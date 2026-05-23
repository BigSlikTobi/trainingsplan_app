import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var store: WatchWorkoutStore

  var body: some View {
    NavigationStack {
      if store.isActive {
        ActiveWorkoutView()
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
      VStack(alignment: .leading, spacing: 10) {
        if store.completedPendingSync {
          Label("Result pending sync", systemImage: "icloud.and.arrow.up")
            .font(.caption)
            .foregroundStyle(.yellow)
        }
        Text(workout.title)
          .font(.headline)
        Text(workout.focus)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("\(workout.exercises.count) exercises")
          .font(.caption2)
          .foregroundStyle(.secondary)
        Button {
          store.start()
        } label: {
          Label("Start", systemImage: "play.fill")
        }
        .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .navigationTitle("T4L")
  }
}

private struct ActiveWorkoutView: View {
  @EnvironmentObject private var store: WatchWorkoutStore

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if let exercise = store.currentExercise {
          Text(exercise.name)
            .font(.headline)
          Text("Set \(store.currentSetNumber)/\(exercise.sets) - \(exercise.reps) reps")
            .font(.caption)
            .foregroundStyle(.secondary)
          if !exercise.coachCue.isEmpty {
            Text(exercise.coachCue)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          if store.restRemaining > 0 {
            Label("\(store.restRemaining)s rest", systemImage: "timer")
              .font(.caption)
              .foregroundStyle(.yellow)
          }
          Stepper("Reps \(store.reps)", value: $store.reps, in: 0...50)
          Stepper("Kg \(store.weightKg, specifier: "%.1f")", value: $store.weightKg, in: 0...250, step: 2.5)
          Stepper("RPE \(store.rpe, specifier: "%.1f")", value: $store.rpe, in: 1...10, step: 0.5)
          Button {
            store.logCurrentSet()
          } label: {
            Label("Done Set", systemImage: "checkmark")
          }
          .buttonStyle(.borderedProminent)
          Button {
            store.skipExercise()
          } label: {
            Label("Skip", systemImage: "forward.end")
          }
        }

        Divider()

        HStack {
          Button {
            store.isPaused ? store.resume() : store.pause()
          } label: {
            Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
          }
          Button(role: .destructive) {
            store.finish()
          } label: {
            Image(systemName: "stop.fill")
          }
        }
      }
      .padding()
    }
    .navigationTitle("Workout")
  }
}
