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
- `lib/src/services/local_bridge_service.dart`: REST client for `t4l-server`.
- `lib/src/services/coach_payload_service.dart`: JSON payload builders and
  result parsers.
- `lib/src/models/fitness_models.dart`: domain models and JSON contracts.
- `ios/Runner/AppDelegate.swift`: native watch sync channel wiring.

## Validation

Run `flutter test` and `flutter analyze` after app changes. For server protocol
changes, run the `t4l-server` test suite in the sibling repository.
