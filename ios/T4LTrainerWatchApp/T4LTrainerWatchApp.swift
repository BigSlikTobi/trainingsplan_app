import SwiftUI

@main
struct T4LTrainerWatchApp: App {
  @State private var store = WatchWorkoutStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(store)
    }
  }
}
