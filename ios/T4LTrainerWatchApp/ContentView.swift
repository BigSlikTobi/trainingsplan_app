import SwiftUI

// ── Design Tokens ──────────────────────────────────────────────────
private enum T {
  static let bg       = Color(red: 0.059, green: 0.071, blue: 0.063)  // #0F1210
  static let surface  = Color(red: 0.094, green: 0.110, blue: 0.102) // #181C1A
  static let surface2 = Color(red: 0.122, green: 0.141, blue: 0.129) // #1F2421
  static let paper    = Color(red: 0.933, green: 0.925, blue: 0.918) // #EEECEA
  static let sage     = Color(red: 0.431, green: 0.541, blue: 0.451) // #6E8A73
  static let coral    = Color(red: 0.796, green: 0.420, blue: 0.322) // #CB6B52
  static let gold     = Color(red: 0.788, green: 0.635, blue: 0.337) // #C9A256

  static func rpeColor(_ rpe: Double) -> Color {
    if rpe <= 4 { return sage }
    if rpe <= 6 { return gold }
    return coral
  }
}

// ── Root ────────────────────────────────────────────────────────────

struct ContentView: View {
  @EnvironmentObject private var store: WatchWorkoutStore

  var body: some View {
    NavigationStack {
      ZStack {
        T.bg.ignoresSafeArea()
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
}

// ── Empty State ─────────────────────────────────────────────────────

private struct EmptyWorkoutView: View {
  var body: some View {
    VStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(T.surface)
          .frame(width: 44, height: 44)
        Image(systemName: "applewatch")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(T.paper.opacity(0.28))
      }
      Text("KEIN WORKOUT")
        .font(.system(size: 9, weight: .heavy))
        .tracking(1.2)
        .foregroundStyle(T.paper.opacity(0.28))
      Text("Öffne die iPhone App")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(T.paper.opacity(0.42))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// ── Today Workout ───────────────────────────────────────────────────

private struct TodayWorkoutView: View {
  @EnvironmentObject private var store: WatchWorkoutStore
  let workout: WatchPlannedWorkout

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if store.completedPendingSync {
          syncBanner
        }
        if store.isWorkoutCompleted {
          completedCard
        } else if let exercise = store.currentExercise, store.hasRemainingExercises {
          nextExerciseCard(exercise)
        } else {
          noExercisesCard
        }
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 8)
    }
    .background(T.bg)
  }

  private var syncBanner: some View {
    HStack(spacing: 5) {
      Image(systemName: "arrow.triangle.2.circlepath")
        .font(.system(size: 10, weight: .semibold))
      Text("Sync ausstehend")
        .font(.system(size: 10, weight: .semibold))
    }
    .foregroundStyle(T.gold)
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(T.gold.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(T.gold.opacity(0.30), lineWidth: 1)
    )
  }

  private func nextExerciseCard(_ exercise: WatchExercise) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 6) {
        statusPill("● BEREIT", color: T.gold)
        Text(workout.title.uppercased())
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(T.paper)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
      }
      .padding(.horizontal, 12)
      .padding(.top, 12)
      .padding(.bottom, 10)

      Divider().overlay(T.paper.opacity(0.06))

      // Next exercise
      VStack(alignment: .leading, spacing: 6) {
        Text("NÄCHSTE ÜBUNG")
          .font(.system(size: 8, weight: .heavy))
          .tracking(1.0)
          .foregroundStyle(T.paper.opacity(0.28))

        Text(exercise.name)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(T.sage)
          .lineLimit(2)
          .minimumScaleFactor(0.8)

        HStack(spacing: 6) {
          Text("\(exercise.sets) × \(exercise.reps)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(T.paper.opacity(0.48))

          Circle()
            .fill(T.rpeColor(exercise.targetRpe).opacity(0.85))
            .frame(width: 5, height: 5)

          Text("RPE \(Int(exercise.targetRpe))")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(T.paper.opacity(0.35))
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      Divider().overlay(T.paper.opacity(0.06))

      // Buttons
      VStack(spacing: 6) {
        Button {
          store.startNextExercise()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "play.fill")
              .font(.system(size: 10))
            Text("START")
              .font(.system(size: 12, weight: .heavy))
              .tracking(0.8)
          }
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 38)
          .background(T.sage)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)

        if store.isActive {
          Button {
            store.finish()
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
              Text("BEENDEN")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
            }
            .foregroundStyle(T.paper.opacity(0.48))
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(T.paper.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .strokeBorder(T.paper.opacity(0.08), lineWidth: 1)
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
    }
    .background(T.surface)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(T.paper.opacity(0.06), lineWidth: 1)
    )
  }

  private var completedCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        statusPill("✓ FERTIG", color: T.sage)

        Text(workout.title.uppercased())
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(T.paper)
          .lineLimit(2)
          .minimumScaleFactor(0.7)

        if let summary = store.summary {
          Text(durationText(summary.totalTime))
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(T.paper)
        }
      }
      .padding(.horizontal, 12)
      .padding(.top, 12)
      .padding(.bottom, 10)

      Divider().overlay(T.paper.opacity(0.06))

      VStack(spacing: 6) {
        Button {
          store.openSummaryOverlay()
        } label: {
          HStack(spacing: 5) {
            Image(systemName: "chart.bar.doc.horizontal")
              .font(.system(size: 10, weight: .semibold))
            Text("DETAILS")
              .font(.system(size: 10, weight: .bold))
              .tracking(0.6)
          }
          .foregroundStyle(T.sage)
          .frame(maxWidth: .infinity)
          .frame(height: 34)
          .background(T.sage.opacity(0.12))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .strokeBorder(T.sage.opacity(0.25), lineWidth: 1)
          )
        }
        .buttonStyle(.plain)

        Text("Warte auf nächstes Workout")
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(T.paper.opacity(0.28))
          .padding(.top, 2)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
    }
    .background(T.surface)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(T.paper.opacity(0.06), lineWidth: 1)
    )
  }

  private var noExercisesCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(workout.title.uppercased())
        .font(.system(size: 14, weight: .heavy))
        .foregroundStyle(T.paper)
        .lineLimit(2)
      Text("Keine offenen Übungen")
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(T.paper.opacity(0.35))
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(T.surface)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(T.paper.opacity(0.06), lineWidth: 1)
    )
  }
}

// ── Active Workout ──────────────────────────────────────────────────

private struct ActiveWorkoutView: View {
  @EnvironmentObject private var store: WatchWorkoutStore
  @ObservedObject var workoutManager: WatchWorkoutManager

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(alignment: .leading, spacing: 0) {
        // Exercise name + status
        VStack(alignment: .leading, spacing: 6) {
          statusPill(
            store.isPaused ? "⏸ PAUSE" : "● AKTIV",
            color: store.isPaused ? T.gold : T.coral
          )

          if let exercise = store.currentExercise {
            Text(exercise.name.uppercased())
              .font(.system(size: 16, weight: .heavy))
              .foregroundStyle(T.paper)
              .lineLimit(2)
              .minimumScaleFactor(0.7)
          }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)

        // Timer
        Text(elapsedText(at: context.date))
          .font(.system(size: 36, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(store.isPaused ? T.gold : T.coral)
          .padding(.horizontal, 12)
          .padding(.bottom, 8)

        Divider().overlay(T.paper.opacity(0.06))

        // Metrics
        HStack(spacing: 0) {
          metricTile("HR", value: heartRateText, color: .red)
          Rectangle()
            .fill(T.paper.opacity(0.06))
            .frame(width: 1)
          metricTile("KCAL", value: caloriesText, color: .orange)
        }
        .frame(height: 44)

        Divider().overlay(T.paper.opacity(0.06))

        // Controls
        HStack(spacing: 8) {
          Button {
            store.isPaused ? store.resume() : store.pause()
          } label: {
            Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(store.isPaused ? .white : T.paper.opacity(0.62))
              .frame(maxWidth: .infinity)
              .frame(height: 38)
              .background(store.isPaused ? T.sage : T.surface2)
              .clipShape(RoundedRectangle(cornerRadius: 10))
              .overlay(
                RoundedRectangle(cornerRadius: 10)
                  .strokeBorder(
                    store.isPaused ? Color.clear : T.paper.opacity(0.10),
                    lineWidth: 1
                  )
              )
          }
          .buttonStyle(.plain)

          Button {
            store.stopCurrentExercise()
          } label: {
            Image(systemName: "stop.fill")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(T.coral)
              .frame(width: 46, height: 38)
              .background(T.coral.opacity(0.13))
              .clipShape(RoundedRectangle(cornerRadius: 10))
              .overlay(
                RoundedRectangle(cornerRadius: 10)
                  .strokeBorder(T.coral.opacity(0.28), lineWidth: 1)
              )
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
      }
      .background(T.surface)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(T.paper.opacity(0.06), lineWidth: 1)
      )
      .padding(.horizontal, 4)
    }
  }

  private func metricTile(_ label: String, value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.system(size: 8, weight: .heavy))
        .tracking(0.8)
        .foregroundStyle(T.paper.opacity(0.28))
      Text(value)
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
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
}

// ── Workout Summary ─────────────────────────────────────────────────

private struct WorkoutSummaryView: View {
  @EnvironmentObject private var store: WatchWorkoutStore
  let summary: WatchWorkoutSummary

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        // Header
        VStack(alignment: .leading, spacing: 8) {
          statusPill("✓ FERTIG", color: T.sage)

          Text(summary.title.uppercased())
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(T.paper)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)

        Divider().overlay(T.paper.opacity(0.06))

        // Stats
        VStack(alignment: .leading, spacing: 10) {
          summaryMetric("DAUER", durationText(summary.totalTime))
          summaryMetric(
            "Ø HR",
            summary.averageHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "—"
          )
          summaryMetric(
            "KCAL",
            summary.totalCalories.map { "\(Int($0.rounded()))" } ?? "—"
          )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)

        Divider().overlay(T.paper.opacity(0.06))

        // Done button
        Button {
          store.dismissSummaryOverlay()
        } label: {
          Text("FERTIG")
            .font(.system(size: 12, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(T.sage)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
      }
      .background(T.surface)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(T.paper.opacity(0.06), lineWidth: 1)
      )
      .padding(.horizontal, 4)
      .padding(.bottom, 8)
    }
    .background(T.bg)
  }

  private func summaryMetric(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 9, weight: .heavy))
        .tracking(1.0)
        .foregroundStyle(T.paper.opacity(0.28))
        .frame(width: 50, alignment: .leading)
      Spacer()
      Text(value)
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(T.paper)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(T.paper.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .strokeBorder(T.paper.opacity(0.06), lineWidth: 1)
    )
  }
}

// ── Shared Components ───────────────────────────────────────────────

private func statusPill(_ label: String, color: Color) -> some View {
  Text(label)
    .font(.system(size: 9, weight: .heavy))
    .tracking(0.8)
    .foregroundStyle(color)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(color.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 99))
    .overlay(
      RoundedRectangle(cornerRadius: 99)
        .strokeBorder(color.opacity(0.30), lineWidth: 1)
    )
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
