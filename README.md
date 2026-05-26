# T4L Trainer

Flutter iOS app for creating home training plans.

For user installation and agent handoff, start with `docs/setup.md`. The app now
syncs with T4L Gym Bro only through the self-hosted `t4l-server` REST API and
agent-facing MCP route.

## Agent coaching workflow

Install and start the local server:

```bash
pipx install t4l-server
t4l-server serve --data-dir ~/T4LServerData
```

Enter the printed server URL and API key in the app Settings screen. The phone
pushes context through REST; T4L Gym Bro reads context and writes pending results
through MCP.

## Apple Watch app

The iOS workspace includes a native SwiftUI watchOS target,
`T4LTrainerWatchApp`, for executing the current workout on Apple Watch. See
`docs/watch_app.md` for signing, first-run, HealthKit, and validation steps.
