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

  /// Heart-rate zone color, reusing the palette.
  static func hrColor(_ bpm: Double) -> Color {
    if bpm < 100 { return sage }
    if bpm < 140 { return gold }
    return coral
  }
}

// ── Root ────────────────────────────────────────────────────────────

struct ContentView: View {
  @Environment(WatchWorkoutStore.self) private var store

  var body: some View {
    NavigationStack {
      ZStack {
        phaseContent
      }
      .containerBackground(backgroundGradient, for: .navigation)
      .animation(.smooth(duration: 0.32), value: store.phase)
    }
  }

  @ViewBuilder private var phaseContent: some View {
    switch store.phase {
    case .countdown:
      CountdownView().transition(.scale(scale: 0.85).combined(with: .opacity))
    case .active:
      ActiveWorkoutView().transition(.opacity)
    case .resting:
      RestView().transition(.opacity)
    case .completed:
      if let summary = store.summary {
        WorkoutSummaryView(summary: summary).transition(.opacity)
      }
    case .ready:
      if let workout = store.workout {
        TodayWorkoutView(workout: workout).transition(.opacity)
      }
    case .idle:
      EmptyWorkoutView().transition(.opacity)
    }
  }

  private var backgroundGradient: LinearGradient {
    let top: Color
    switch store.phase {
    case .countdown, .active: top = T.coral.opacity(0.22)
    case .resting: top = T.gold.opacity(0.20)
    case .completed: top = T.sage.opacity(0.18)
    default: top = T.surface.opacity(0.55)
    }
    return LinearGradient(colors: [top, T.bg], startPoint: .top, endPoint: .center)
  }
}

// ── Empty State ─────────────────────────────────────────────────────

private struct EmptyWorkoutView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "applewatch")
        .font(.system(size: 30, weight: .semibold))
        .foregroundStyle(T.paper.opacity(0.3))
        .frame(width: 64, height: 64)
        .background(T.surface, in: Circle())
      Text("KEIN WORKOUT")
        .font(.system(size: 13, weight: .heavy)).tracking(1.2)
        .foregroundStyle(T.paper.opacity(0.4))
      Text("Öffne die iPhone App")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(T.paper.opacity(0.5))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// ── Countdown (3 · 2 · 1) ───────────────────────────────────────────

private struct CountdownView: View {
  @Environment(WatchWorkoutStore.self) private var store

  var body: some View {
    VStack(spacing: 8) {
      Text(store.currentExercise?.name.uppercased() ?? "BEREIT MACHEN")
        .font(.system(size: 17, weight: .heavy)).tracking(0.4)
        .foregroundStyle(T.paper.opacity(0.7))
        .lineLimit(2).minimumScaleFactor(0.6)
        .multilineTextAlignment(.center)

      if let end = store.countdownEndsAt {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
          let remaining = max(0, end.timeIntervalSince(context.date))
          Text("\(max(1, Int(remaining.rounded(.up))))")
            .font(.system(size: 110, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(T.coral)
        }
      }

      Text("Tippen zum Starten")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(T.paper.opacity(0.4))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
    .onTapGesture { store.skipCountdown() }
  }
}

// ── Today / Plan (ready) ────────────────────────────────────────────

private struct TodayWorkoutView: View {
  @Environment(WatchWorkoutStore.self) private var store
  let workout: WatchPlannedWorkout

  var body: some View {
    if store.isWorkoutCompleted {
      CompletedCard(workout: workout)
    } else {
      List {
        if store.workoutManager.authState == .denied {
          healthPermissionRow.listRowBackground(Color.clear)
        }
        heroRow.listRowBackground(Color.clear)
        ForEach(Array(workout.exercises.enumerated()), id: \.element.exerciseId) { index, exercise in
          exerciseRow(exercise, isCurrent: index == store.exerciseIndex)
        }
      }
      .listStyle(.carousel)
      .scrollContentBackground(.hidden)
    }
  }

  private var heroRow: some View {
    VStack(alignment: .leading, spacing: 12) {
      statusPill("● BEREIT", color: T.gold)

      if let exercise = store.currentExercise {
        Text(exercise.name)
          .font(.system(size: 22, weight: .heavy))
          .foregroundStyle(T.sage)
          .lineLimit(2).minimumScaleFactor(0.7)
        HStack(spacing: 8) {
          Text("\(exercise.sets) × \(exercise.reps)")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(T.paper)
          Circle().fill(T.rpeColor(exercise.targetRpe)).frame(width: 7, height: 7)
          Text("RPE \(Int(exercise.targetRpe))")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(T.paper.opacity(0.5))
        }
      } else {
        Text(workout.title)
          .font(.system(size: 20, weight: .heavy))
          .foregroundStyle(T.paper)
          .lineLimit(2).minimumScaleFactor(0.7)
      }

      Button { store.beginExercise() } label: {
        HStack(spacing: 8) {
          Image(systemName: "play.fill").font(.system(size: 16, weight: .bold))
          Text("START").font(.system(size: 19, weight: .heavy)).tracking(0.5)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).frame(height: 52)
        .background(T.sage, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)

      if store.isActive {
        Button { store.finish() } label: {
          Text("WORKOUT BEENDEN")
            .font(.system(size: 13, weight: .bold)).tracking(0.4)
            .foregroundStyle(T.paper.opacity(0.55))
            .frame(maxWidth: .infinity).frame(height: 38)
            .background(T.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.vertical, 4)
  }

  private var healthPermissionRow: some View {
    HStack(spacing: 8) {
      Image(systemName: "heart.text.square")
        .font(.system(size: 20, weight: .semibold)).foregroundStyle(T.coral)
      Text("Health-Zugriff aktivieren, damit der Bildschirm aktiv bleibt.")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(T.paper.opacity(0.7))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(T.coral.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14).strokeBorder(T.coral.opacity(0.28), lineWidth: 1)
    )
  }

  private func exerciseRow(_ exercise: WatchExercise, isCurrent: Bool) -> some View {
    HStack(spacing: 10) {
      Circle()
        .fill(isCurrent ? T.sage : T.paper.opacity(0.2))
        .frame(width: 8, height: 8)
      VStack(alignment: .leading, spacing: 2) {
        Text(exercise.name)
          .font(.system(size: 16, weight: isCurrent ? .heavy : .semibold))
          .foregroundStyle(isCurrent ? T.paper : T.paper.opacity(0.65))
          .lineLimit(1).minimumScaleFactor(0.7)
        Text("\(exercise.sets) × \(exercise.reps)")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(T.paper.opacity(0.45))
      }
      Spacer(minLength: 4)
      if isCurrent {
        Image(systemName: "arrow.right.circle.fill")
          .font(.system(size: 18)).foregroundStyle(T.sage)
      }
    }
    .listRowBackground(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(isCurrent ? T.sage.opacity(0.16) : T.surface)
    )
  }
}

private struct CompletedCard: View {
  @Environment(WatchWorkoutStore.self) private var store
  let workout: WatchPlannedWorkout

  var body: some View {
    VStack(spacing: 12) {
      statusPill("✓ FERTIG", color: T.sage)
      if let summary = store.summary {
        Text(durationText(summary.totalTime))
          .font(.system(size: 46, weight: .bold, design: .rounded))
          .monospacedDigit().foregroundStyle(T.paper)
          .minimumScaleFactor(0.5).lineLimit(1)
      }
      Text(workout.title)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(T.paper.opacity(0.55))
        .multilineTextAlignment(.center)
        .lineLimit(2).minimumScaleFactor(0.7)

      Button { store.openSummaryOverlay() } label: {
        HStack(spacing: 6) {
          Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 15, weight: .semibold))
          Text("DETAILS").font(.system(size: 15, weight: .bold)).tracking(0.5)
        }
        .foregroundStyle(T.sage)
        .frame(maxWidth: .infinity).frame(height: 46)
        .background(T.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// ── Active Workout (paged) ──────────────────────────────────────────

private struct ActiveWorkoutView: View {
  @Environment(WatchWorkoutStore.self) private var store
  @State private var page = 1

  var body: some View {
    TabView(selection: $page) {
      ControlsPage().tag(0)
      MetricsPage().tag(1)
      UpNextPage().tag(2)
    }
    .tabViewStyle(.verticalPage)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          store.isPaused ? store.resume() : store.pause()
        } label: {
          Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(store.isPaused ? T.gold : T.coral)
        }
      }
    }
  }
}

private struct MetricsPage: View {
  @Environment(WatchWorkoutStore.self) private var store
  @Environment(\.isLuminanceReduced) private var dimmed

  var body: some View {
    VStack(spacing: 6) {
      if let exercise = store.currentExercise {
        Text(exercise.name.uppercased())
          .font(.system(size: 14, weight: .heavy)).tracking(0.3)
          .foregroundStyle(store.isPaused ? T.gold : T.coral)
          .lineLimit(2).minimumScaleFactor(0.7)
          .multilineTextAlignment(.center)
      }

      Spacer(minLength: 0)
      elapsedTimer
      Spacer(minLength: 0)

      HStack(spacing: 6) {
        heartMetric
        energyMetric
      }

      Spacer(minLength: 0)
      doneButton
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .opacity(dimmed ? 0.85 : 1)
  }

  @ViewBuilder private var elapsedTimer: some View {
    Group {
      if let startedAt = store.activeExerciseStartedAt {
        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
      } else {
        Text("00:00")
      }
    }
    .font(.system(size: 54, weight: .bold, design: .rounded))
    .monospacedDigit()
    .lineLimit(1).minimumScaleFactor(0.5)
    .foregroundStyle(store.isPaused ? T.gold : T.paper)
  }

  private var heartMetric: some View {
    let hr = store.workoutManager.currentHeartRateBpm
    return HStack(spacing: 4) {
      Image(systemName: "heart.fill")
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(hr.map(T.hrColor) ?? T.paper.opacity(0.3))
        .symbolEffect(.pulse, options: .repeating, isActive: hr != nil)
      Text(hr.map { "\(Int($0.rounded()))" } ?? "--")
        .font(.system(size: 40, weight: .bold, design: .rounded))
        .monospacedDigit().foregroundStyle(T.paper)
        .lineLimit(1).minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity)
  }

  private var energyMetric: some View {
    HStack(spacing: 4) {
      Image(systemName: "flame.fill")
        .font(.system(size: 17, weight: .bold)).foregroundStyle(.orange)
      Text(store.workoutManager.activeEnergyKcal.map { "\(Int($0.rounded()))" } ?? "--")
        .font(.system(size: 36, weight: .bold, design: .rounded))
        .monospacedDigit().foregroundStyle(T.paper)
        .lineLimit(1).minimumScaleFactor(0.6)
    }
    .frame(maxWidth: .infinity)
  }

  private var doneButton: some View {
    Button { store.stopCurrentExercise() } label: {
      HStack(spacing: 8) {
        Image(systemName: "checkmark").font(.system(size: 18, weight: .heavy))
        Text("FERTIG").font(.system(size: 19, weight: .heavy)).tracking(0.5)
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity).frame(height: 52)
      .background(T.sage, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

private struct ControlsPage: View {
  @Environment(WatchWorkoutStore.self) private var store

  var body: some View {
    VStack(spacing: 10) {
      Button {
        store.isPaused ? store.resume() : store.pause()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
            .font(.system(size: 20, weight: .bold))
          Text(store.isPaused ? "WEITER" : "PAUSE")
            .font(.system(size: 19, weight: .heavy)).tracking(0.5)
        }
        .foregroundStyle(store.isPaused ? .white : T.paper.opacity(0.8))
        .frame(maxWidth: .infinity).frame(height: 58)
        .background(store.isPaused ? T.sage : T.surface2, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
      }
      .buttonStyle(.plain)

      Button { store.finish() } label: {
        HStack(spacing: 8) {
          Image(systemName: "stop.fill").font(.system(size: 18, weight: .bold))
          Text("BEENDEN").font(.system(size: 18, weight: .heavy)).tracking(0.4)
        }
        .foregroundStyle(T.coral)
        .frame(maxWidth: .infinity).frame(height: 58)
        .background(T.coral.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 15, style: .continuous)
            .strokeBorder(T.coral.opacity(0.3), lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct UpNextPage: View {
  @Environment(WatchWorkoutStore.self) private var store

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("ALS NÄCHSTES")
        .font(.system(size: 12, weight: .heavy)).tracking(1.0)
        .foregroundStyle(T.paper.opacity(0.4))

      let upcoming = store.upcomingExercises
      if upcoming.isEmpty {
        Spacer()
        HStack {
          Spacer()
          Text("Letzte Übung 💪")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(T.sage)
          Spacer()
        }
        Spacer()
      } else {
        ForEach(upcoming.prefix(4)) { exercise in
          HStack(spacing: 10) {
            Circle().fill(T.paper.opacity(0.2)).frame(width: 7, height: 7)
            Text(exercise.name)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(T.paper.opacity(0.75))
              .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            Text("\(exercise.sets)×\(exercise.reps)")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(T.paper.opacity(0.45))
          }
        }
        Spacer()
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

// ── Rest Period (Digital Crown adjustable) ──────────────────────────

private struct RestView: View {
  @Environment(WatchWorkoutStore.self) private var store
  @Environment(\.isLuminanceReduced) private var dimmed
  @State private var crown = 0.0

  var body: some View {
    VStack(spacing: 8) {
      statusPill("● PAUSE", color: T.gold)

      Spacer(minLength: 0)
      bigCountdown
      Spacer(minLength: 0)

      if let next = store.currentExercise {
        Text(next.name)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(T.sage)
          .lineLimit(2).minimumScaleFactor(0.7)
          .multilineTextAlignment(.center)
      }

      Spacer(minLength: 0)
      controls
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .opacity(dimmed ? 0.88 : 1)
    .focusable()
    .digitalCrownRotation(
      $crown, from: -600, through: 600, by: 15,
      sensitivity: .low, isContinuous: true, isHapticFeedbackEnabled: true
    )
    .onChange(of: crown) { oldValue, newValue in
      let delta = Int((newValue - oldValue).rounded())
      if delta != 0 { store.addRestSeconds(delta) }
    }
  }

  @ViewBuilder private var bigCountdown: some View {
    if let start = store.restStartedAt, let end = store.restEndsAt {
      Text(timerInterval: start...end, countsDown: true)
        .font(.system(size: 68, weight: .bold, design: .rounded))
        .monospacedDigit().foregroundStyle(T.gold)
        .lineLimit(1).minimumScaleFactor(0.5)
    }
  }

  private var controls: some View {
    HStack(spacing: 8) {
      Button { store.beginExercise() } label: {
        HStack(spacing: 6) {
          Image(systemName: "forward.fill").font(.system(size: 15, weight: .bold))
          Text("START").font(.system(size: 17, weight: .heavy)).tracking(0.5)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity).frame(height: 50)
        .background(T.sage, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
      }
      .buttonStyle(.plain)

      Button { store.finish() } label: {
        Image(systemName: "checkmark")
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(T.paper.opacity(0.55))
          .frame(width: 56, height: 50)
          .background(T.paper.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
          .overlay(
            RoundedRectangle(cornerRadius: 13).strokeBorder(T.paper.opacity(0.1), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
    }
  }
}

// ── Workout Summary ─────────────────────────────────────────────────

private struct WorkoutSummaryView: View {
  @Environment(WatchWorkoutStore.self) private var store
  let summary: WatchWorkoutSummary

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        statusPill("✓ FERTIG", color: T.sage)

        summaryMetric(
          icon: "clock.fill", tint: T.paper,
          value: durationText(summary.totalTime)
        )
        summaryMetric(
          icon: "heart.fill", tint: T.coral,
          value: summary.averageHeartRate.map { "\(Int($0.rounded()))" } ?? "—"
        )
        summaryMetric(
          icon: "flame.fill", tint: .orange,
          value: summary.totalCalories.map { "\(Int($0.rounded()))" } ?? "—"
        )

        Button { store.dismissSummaryOverlay() } label: {
          Text("FERTIG")
            .font(.system(size: 17, weight: .heavy)).tracking(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 50)
            .background(T.sage, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
    }
  }

  private func summaryMetric(icon: String, tint: Color, value: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
        .frame(width: 26)
      Spacer(minLength: 4)
      Text(value)
        .font(.system(size: 30, weight: .bold, design: .rounded))
        .monospacedDigit().foregroundStyle(T.paper)
        .lineLimit(1).minimumScaleFactor(0.5)
    }
    .padding(.horizontal, 14).padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .background(T.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

// ── Shared Components ───────────────────────────────────────────────

private func statusPill(_ label: String, color: Color) -> some View {
  Text(label)
    .font(.system(size: 12, weight: .heavy)).tracking(0.8)
    .foregroundStyle(color)
    .padding(.horizontal, 11).padding(.vertical, 5)
    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 99))
    .overlay(
      RoundedRectangle(cornerRadius: 99).strokeBorder(color.opacity(0.32), lineWidth: 1)
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
