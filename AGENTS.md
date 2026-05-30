# T4L Trainer Agent Notes

This Flutter iOS app is the phone UI for T4L Gym Bro. The phone remains the
source of truth for accepted training state.

## Supported Agent Flow

- Use `t4l-server serve --data-dir ~/T4LServerData`.
- Enter the printed server URL and API key in the app Settings screen.
- Push app context from Settings before coaching.
- Agents use the `t4l-server` MCP endpoint to read context and write pending
  results.
- The app pulls pending results through REST. Training blocks require explicit
  user import; next-day plans, nutrition analysis, and fuel guidance are applied
  from server result payloads.

There is no supported folder-based sync or helper script flow.

## Code Map

- `lib/src/state/fitness_controller.dart`: app state and server sync workflow.
  Server results are applied via `_ResultImport` outcomes — malformed payloads
  are consumed once (never re-pulled) so the sync loop can't wedge. While an
  Apple Watch session owns the workout (`isWatchControllingSession`), the phone
  defers exercise start/stop to the watch (single source of truth) and does not
  echo the watch's own progress back; with no watch session the phone owns it.
- `lib/src/services/local_bridge_service.dart`: REST client for `t4l-server`.
- `lib/src/services/coach_payload_service.dart`: JSON payload builders and
  result parsers.
- `lib/src/models/fitness_models.dart`: domain models and JSON contracts.
- `lib/src/ui/dashboard.dart`: app shell + Today/Settings UI. The Nutrition,
  Coach, and Progress tabs live in `dashboard_nutrition.dart`,
  `dashboard_coach.dart`, and `dashboard_progress.dart` as library `part`s of
  `dashboard.dart` (shared private scope; add new `part` files the same way).
- `lib/src/design/design_tokens.dart`: color, spacing, radii, type scale
  (`AppType`), motion (`AppMotion`), and opacity tokens. Prefer these over
  inline literals.
- `lib/src/util/app_log.dart`: structured logging (`AppLog`). Log caught
  exceptions here instead of swallowing them into status strings only.
- `lib/src/util/haptics.dart`: semantic haptic feedback for key interactions.
- `ios/Runner/AppDelegate.swift`: native watch sync channel wiring.
- `ios/Runner/WatchSyncCoordinator.swift`: phone side of the watch link
  (WatchConnectivity ↔ Flutter event channel).

### Apple Watch app (`ios/T4LTrainerWatchApp/`, watchOS 10+, SwiftUI)

- `WatchContract.swift`: single source of truth for the watch↔phone wire
  contract — WatchConnectivity message keys (`WatchMessageKey`), `UserDefaults`
  keys, the `HealthAuthState` status enum (raw values are sent to the phone in
  `healthWriteStatus`; keep them stable), reusable ISO-8601 formatters
  (`WatchClock`), and semantic haptics (`WatchHaptics`). The phone side mirrors
  these string values in `WatchSyncCoordinator.swift` — keep both in sync.
- `WatchWorkoutManager.swift`: HealthKit engine (`@Observable @MainActor`). Owns
  one `HKWorkoutSession` for the *entire* workout — this, plus the
  `workout-processing` background mode in `Info.plist`, is what keeps the app
  alive (frontmost + background-running) during training. The session starts
  whenever HealthKit is available and is **never** gated on read-authorization
  success, so denied heart-rate access degrades metrics rather than disabling
  the keep-alive. Live metrics are computed on the builder's queue and published
  on the main actor (no cross-thread shared state).
- `WatchWorkoutStore.swift`: workout view-model (`@Observable @MainActor`).
  Drives the phased flow (`WatchPhase`: ready → countdown → active → resting →
  completed; `beginExercise()` runs the 3-2-1 pre-roll before the unchanged
  `startNextExercise()`), keeping the session alive across exercises and rest.
  The countdown and rest period (crown-adjustable via `addRestSeconds`) are
  watch-only UI state and are not part of the wire contract. While the watch
  is running the session it started (`startedOnWatch`), it ignores inbound
  active-log echoes for that workout (ownership guard) so a phone re-sync can't
  reset its live timer / exercise index.
- `ContentView.swift`: SwiftUI surface, structured around `store.phase`
  (idle/ready/countdown/active/resting/completed) with animated transitions and
  a phase-tinted `.containerBackground` that bleeds to the display corners. The
  active workout is a paged `TabView(.verticalPage)` — Controls / Metrics /
  Up Next — with a `Gauge` + pulsing-heart HR readout and a corner pause
  toolbar item; the ready screen is a `.carousel` plan list; rest is
  Digital-Crown adjustable (±15 s); a 3-2-1 countdown precedes each exercise.
  Uses `Text(timerInterval:)` and always-on (`isLuminanceReduced`) awareness so
  timers stay efficient and legible wrist-down. Visual tokens live in the
  private `T` enum.
- `WatchConnectivityManager.swift`: watch side of the link; sends progress and
  completions, receives planned workouts. All keys come from `WatchContract`.

## Conventions

- `analysis_options.yaml` enables strict casts/raw types plus
  `cancel_subscriptions`, `close_sinks`, and `use_build_context_synchronously`
  as errors. Keep `flutter analyze` clean.
- Inject services through the `FitnessController` constructor for tests
  (`store`, `health`, `media`, `bridge`, `watchSync`).

## Validation

Run `flutter test` and `flutter analyze` after app changes. For server protocol
changes, run the `t4l-server` test suite in the sibling repository.

For Apple Watch (`ios/T4LTrainerWatchApp/`) changes, build the watch target:

```bash
xcodebuild -project ios/Runner.xcodeproj -scheme T4LTrainerWatchApp \
  -sdk watchsimulator26.2 -destination 'generic/platform=watchOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

The editor's SourceKit may flag watchOS-only APIs (HealthKit, WatchConnectivity,
WatchKit) as "unavailable in macOS" or "No such module" — those are host-SDK
indexing false positives. The watch-target build above is authoritative.
