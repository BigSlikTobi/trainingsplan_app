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
  are consumed once (never re-pulled) so the sync loop can't wedge.
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

## Conventions

- `analysis_options.yaml` enables strict casts/raw types plus
  `cancel_subscriptions`, `close_sinks`, and `use_build_context_synchronously`
  as errors. Keep `flutter analyze` clean.
- Inject services through the `FitnessController` constructor for tests
  (`store`, `health`, `media`, `bridge`, `watchSync`).

## Validation

Run `flutter test` and `flutter analyze` after app changes. For server protocol
changes, run the `t4l-server` test suite in the sibling repository.
