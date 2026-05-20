# T4L Trainer

Flutter iOS app for creating home training plans.

For user installation and agent handoff, start with
`docs/setup.md`. It explains the iCloud exchange folder, daily agent workflow,
and how Codex, Claude, or another agent should process the app's context files.
Agents that do not need the full repository can fetch the public bootstrap guide
shown in the app's `Setup` tab.

## OpenAI setup

Do not commit an API key into the repository.

Run from Flutter:

```bash
flutter run \
  --dart-define=OPENAI_API_KEY=sk-your-key \
  --dart-define=OPENAI_MODEL=gpt-5.2
```

`OPENAI_MODEL` is optional. The app defaults to `gpt-5.2`.

For Xcode deployment, add these as Flutter build defines in the run/build arguments:

```text
--dart-define=OPENAI_API_KEY=sk-your-key
--dart-define=OPENAI_MODEL=gpt-5.2
```

The app uses the OpenAI Responses API to return a structured JSON training plan. If the key is missing or the request fails, the local plan generator remains available.

## Agent coaching workflow

The app can exchange JSON plans and nutrition analysis with Codex, Claude, or
another agent through iCloud. In the iPhone app, export a block request from the
`Blocks` tab, discuss the plan with the agent, then write the final
`training_block_plan.json` back to the exchange folder:

```bash
python3 tools/write_training_block_plan.py plan.json
```

See `docs/setup.md` for first-run setup and
`docs/codex_coach_workflow.md` for the coaching flow and JSON contract.
