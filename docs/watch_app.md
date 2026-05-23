# T4L Trainer Apple Watch App

The repository includes a native SwiftUI watchOS companion target named
`T4LTrainerWatchApp`. The Flutter iPhone app remains the source of truth for
plans and history; the watch app executes the current workout and syncs the
completed log back through WatchConnectivity.

## First Run

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the `Runner` scheme and a paired iPhone device.
3. Confirm signing uses development team `5A34C2WAYH` for both `Runner` and
   `T4LTrainerWatchApp`.
4. Build and run `Runner` on the iPhone. Xcode embeds the watch app.
5. On the iPhone app, import or create a current training block so `nextWorkout`
   exists, then open the app once to sync the watch payload.
6. Open `T4L Trainer` on Apple Watch and grant Health permissions when asked.

## Training Flow

- Start from the watch or iPhone.
- The watch shows one exercise/set at a time.
- Log reps, kg, and RPE, then tap `Done Set`.
- Rest uses the exercise `restSeconds` value and plays a haptic when complete.
- Finishing the workout writes a functional strength training workout through
  HealthKit when permission is available.
- If the phone is unreachable, the watch keeps the completed result queued and
  retries through WatchConnectivity.

## Validation Commands

```bash
flutter analyze
flutter test
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -destination 'generic/platform=iOS' build
xcodebuild -workspace ios/Runner.xcworkspace -scheme T4LTrainerWatchApp -configuration Debug -destination 'generic/platform=watchOS' build
```

Simulator builds can catch compile issues, but real Apple Watch testing is
required for HealthKit workout sessions, haptics, and paired-device delivery.
