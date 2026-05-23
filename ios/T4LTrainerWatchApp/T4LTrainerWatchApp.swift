import SwiftUI

@main
struct T4LTrainerWatchApp: App {
  @StateObject private var store = WatchWorkoutStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
    }
  }
}
