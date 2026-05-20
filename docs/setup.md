# Agent Setup Guide

Use this file as the first read when a user installs the app and wants to hand
daily coaching to Codex, Claude, or another agent. Codex is the preferred
desktop workflow, but the same iCloud files and helper scripts work for any
agent that can read and write local JSON files.

For agents that should not receive the full repository, use the public bootstrap
guide instead:

```text
https://gist.githubusercontent.com/BigSlikTobi/90ff2ce6c7ab3e37e27eabd48f003afa/raw/t4l_agent_bootstrap.md
```

The app's Setup tab copies this URL together with the user's local exchange
folder path.

## Prerequisites

- Install and open the iOS app once so it can create its local data and iCloud
  exchange folder.
- Enable iCloud Drive for the Apple ID used by the iPhone and Mac.
- Grant HealthKit permissions if the user wants recovery, activity, body
  weight, and nutrition signals included in daily context.
- Complete the profile in the app: goal, body metrics, training days, session
  length, equipment, constraints, preferences, and nutrition context.
- Add or review active entries in the Coach tab `Memory Wiki`. These memories
  are durable agent context for goals, constraints, nutrition patterns,
  recovery signals, preferences, and form cues.
- Optional: provide `OPENAI_API_KEY` when running the Flutter app if the app
  should generate plans through the OpenAI Responses API. The iCloud agent
  workflow does not require committing or storing an API key in the repository.

## Locate The Exchange Folder

From the repository root, print the resolved iCloud exchange directory:

```bash
python3 tools/write_training_block_plan.py --print-dir
```

The folder is usually inside the Mac's Mobile Documents area and ends with:

```text
Documents/CodexFitnessExchange
```

If automatic resolution is wrong, pass the folder explicitly when writing a
result:

```bash
TRAININGSPLAN_EXCHANGE_DIR="/absolute/path/to/CodexFitnessExchange" \
  python3 tools/write_training_block_plan.py plan.json
```

Use the training block helper above as the canonical folder check. If another
helper prints a different folder on a local machine, reuse the canonical folder
with `--exchange-dir` or `TRAININGSPLAN_EXCHANGE_DIR` so all files land in the
same `CodexFitnessExchange` directory.

## Agent Startup Checklist

1. Read this file.
2. Read `docs/codex_coach_workflow.md` for the full file contract and coaching
   rules.
3. Resolve the exchange folder with `python3 tools/write_training_block_plan.py
   --print-dir`.
4. Inspect available exchange files before giving advice. Common files are:
   `day_context.json`, `daily_snapshot.json`, `athlete_profile.json`,
   `training_block_request.json`, `nutrition_analysis_request.json`,
   `training_block_plan.json`, `next_day_plan.json`, and
   `nutrition_analysis_result.json`.
5. Treat `day_context.json` as the primary current-day file when it exists.
   Use `daily_snapshot.json` and `athlete_profile.json` as fallback or
   supporting context.
6. Separate facts from assumptions. Missing HealthKit metrics or omitted JSON
   fields are unknown, not zero.
7. Process the current day using the morning planning loop:
   - Review long-term goal, current block goal, current week, next workout,
     recent workout performance, recovery, activity load, nutrition logs, and
     active `memoryWiki` entries.
   - Decide whether today's training should progress, hold, substitute,
     deload, or rest.
   - Give concise food-based nutrition guidance based on today's training,
     yesterday's intake pattern, recovery, preferences, and digestion context.
   - Ask the user before changing direction when goals, constraints, schedule,
     injury notes, or recovery signals conflict.
8. Write app-consumed JSON only through the validated helper scripts whenever a
   helper exists.

## Codex Automation

In Codex, create a daily morning automation that runs against this repository
and uses the exchange folder as the source of truth. The automation prompt
should say:

```text
Fetch and read the T4L Trainer bootstrap guide:
https://gist.githubusercontent.com/BigSlikTobi/90ff2ce6c7ab3e37e27eabd48f003afa/raw/t4l_agent_bootstrap.md

Use the CodexFitnessExchange folder as the source of truth. Inspect
day_context.json, daily_snapshot.json, athlete_profile.json,
training_block_request.json, nutrition_analysis_request.json, active memoryWiki,
recent training logs, nutrition logs, and HealthKit activity summaries. Produce
a morning coaching plan for today. Decide whether training should progress,
hold, substitute, deload, or rest. Treat nutrition as contextual food guidance,
not fixed targets unless the user asks for targets. Use yesterday's intake as a
soft training-readiness signal and suggest concrete meals that fit today's
training. Do not invent missing health data.
```

Schedule it for the user's preferred morning time. The app writes
`day_context.json` only after explicit pushes, workout completion, and meal
analysis export, so the automation should report when the context appears stale
and ask the user to export a fresh daily context from the app.

## Generic Agent Setup

For Claude or another agent, use the same operating contract:

- Give the agent this repository and the resolved `CodexFitnessExchange` folder.
- Tell it to read `docs/setup.md` first, then `docs/codex_coach_workflow.md`.
- Run it manually each morning or schedule it with the tool that agent supports.
- Require it to inspect the exchange files before coaching.
- Require validated writes:
  - `python3 tools/write_training_block_plan.py plan.json`
  - `python3 tools/write_nutrition_analysis_result.py --exchange-dir
    "/absolute/path/to/CodexFitnessExchange" result.json`
- Require a user confirmation step before overwriting training direction,
  ignoring constraints, or making a recommendation from stale context.

## Safe Defaults

- Prefer morning planning over evening review unless the user asks otherwise.
- Keep recommendations concrete and short enough to act on today.
- Do not overwrite user intent with generic fitness advice.
- Do not treat missing data as evidence.
- Do not store API keys in files.
- Leave generated build outputs, Flutter tool state, and iOS Pods alone unless
  the user explicitly asks for app development work.
