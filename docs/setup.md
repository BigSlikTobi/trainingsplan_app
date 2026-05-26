# T4L Gym Bro Setup Guide

Use this when installing the app and connecting it to T4L Gym Bro.

## Prerequisites

- Open the iOS app once so it can create local training data.
- Install the self-hosted server on the computer or host that will run the agent:

```bash
pipx install t4l-server
t4l-server serve --data-dir ~/T4LServerData
```

- Enter the printed server URL and API key in the app Settings screen, then tap
  `Connect`.
- Grant HealthKit permissions if recovery, activity, body weight, and nutrition
  signals should be included in context.
- Complete the app profile and review active Coach tab `Memory Wiki` entries.

## Workflow

1. Tap `Push Context` before coaching. The phone sends profile, day context, and
   daily snapshot through REST.
2. T4L Gym Bro connects to the printed MCP URL and reads context with MCP tools.
3. T4L Gym Bro writes pending results through MCP, including next-day plans,
   training blocks, nutrition analysis, and fuel guidance.
4. The app checks results through REST. Next-day plans, nutrition results, and
   fuel guidance import directly; training blocks remain pending until the user
   taps `Import`.
5. Missing HealthKit fields mean unknown, not zero.

No folder-based sync or local helper scripts are part of the supported flow.
