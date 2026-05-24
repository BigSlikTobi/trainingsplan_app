# Agent Setup Guide

Use this file as the first read when a user installs the app and wants to hand
daily coaching to Codex, Claude, Gemini, or another local agent.

The canonical agent instructions live in the public repo:

```text
https://github.com/BigSlikTobi/t4l-agent-instructions
```

The supported agent transport is the Self-Hosted T4L Server.

## Prerequisites

- Install and open the iOS app once so it can create local training data.
- Install the T4L server package on the computer that will run the agent:

```bash
pipx install t4l-server
```

- Grant HealthKit permissions if the user wants recovery, activity, body
  weight, and nutrition signals included in daily context.
- Complete the profile in the app: goal, body metrics, training days, session
  length, equipment, constraints, preferences, and nutrition context.
- Add or review active entries in the Coach tab `Memory Wiki`. These memories
  are durable agent context for goals, constraints, nutrition patterns,
  recovery signals, preferences, and form cues.

## Start The Server

Run the server on the same computer as the agent, on a home server, or on a
private VPS:

```bash
t4l-server serve --data-dir ~/T4LServerData
```

The command prints:

```text
Server URL: http://<local-ip>:8787
API key: 123-456
```

Enter the Server URL and API key in the app Settings screen, tap
`Connect`, then tap `Push Context`.

If the computer restarts, sleeps, changes network, or the server process stops,
restart the server and reconnect with the newly printed URL/API key.

## Agent Startup Checklist

1. Read the public agent instructions repo:
   `https://github.com/BigSlikTobi/t4l-agent-instructions`.
2. Use the adapter for the current runtime:
   `agents/codex/SKILL.md`, `agents/claude/CLAUDE.md`, or
   `agents/gemini/GEMINI.md`.
3. Verify `t4l-server` is installed. If missing, ask the user before installing
   the official local package.
4. Start or reuse the server with:
   `t4l-server serve --data-dir ~/T4LServerData`.
5. Wait for the user to connect the app and tap `Push Context`.
6. Inspect available exchange files before giving advice. Common files are:
   `day_context.json`, `daily_snapshot.json`, `athlete_profile.json`,
   `training_block_request.json`, `nutrition_analysis_request.json`,
   `training_block_plan.json`, `next_day_plan.json`,
   `nutrition_analysis_result.json`, and `fuel_guidance.json`.
7. Treat `day_context.json` as the primary current-day file when it exists.
   Use `daily_snapshot.json` and `athlete_profile.json` as fallback or
   supporting context.
8. Separate facts from assumptions. Missing HealthKit metrics or omitted JSON
   fields are unknown, not zero.
9. Process the current day using the morning planning loop:
   - Review long-term goal, current block goal, current week, next workout,
     recent workout performance, recovery, activity load, nutrition logs, and
     active `memoryWiki` entries.
   - Decide whether today's training should progress, hold, substitute,
     deload, or rest.
   - For the daily workflow, write one `next_day_plan.json` workout through
     `python3 tools/write_next_day_plan.py plan.json`. Do not write
     `training_block_plan.json` unless the user explicitly asks for a full
     training block.
   - Give concise food-based nutrition guidance based on today's training,
     yesterday's intake pattern, recovery, preferences, and digestion context.
   - Ask the user before changing direction when goals, constraints, schedule,
     injury notes, or recovery signals conflict.
10. Write app-consumed JSON only through the validated helper scripts whenever a
    helper exists.

## Codex Automation

In Codex, create a daily morning automation that runs against this repository
and uses the Self-Hosted T4L Server exchange folder as the source of truth. The
automation prompt should say:

```text
Read the T4L agent instructions repo:
https://github.com/BigSlikTobi/t4l-agent-instructions

Use agents/codex/SKILL.md. Verify or start:
t4l-server serve --data-dir ~/T4LServerData

Wait for fresh app context from the Self-Hosted T4L Server before coaching. Inspect
day_context.json, daily_snapshot.json, athlete_profile.json,
training_block_request.json, nutrition_analysis_request.json, active memoryWiki,
recent training logs, nutrition logs, and HealthKit activity summaries. Produce
a morning coaching plan for today. Decide whether training should progress,
hold, substitute, deload, or rest. Treat nutrition as contextual food guidance,
not fixed targets unless the user asks for targets. Do not invent missing
health data.
```

The app writes `day_context.json` only after explicit pushes, workout
completion, and meal analysis export, so the automation should report when the
context appears stale and ask the user to push fresh context from the app.

## Generic Agent Setup

For Claude, Gemini, or another agent, use the same operating contract:

- Give the agent the local instructions repo and the server folder.
- Require it to inspect the exchange files before coaching.
- Require the daily plan write:
  - `python3 tools/write_next_day_plan.py plan.json`
- Require validated writes for full block and nutrition artifacts:
  - `python3 tools/write_training_block_plan.py plan.json`
  - `python3 tools/write_nutrition_analysis_result.py --exchange-dir
    "/absolute/path/to/CodexFitnessExchange" result.json`
  - `python3 tools/write_fuel_guidance.py guidance.json`
- Require a user confirmation step before overwriting training direction,
  ignoring constraints, or making a recommendation from stale context.

## Safe Defaults

- Prefer morning planning over evening review unless the user asks otherwise.
- Keep recommendations concrete and short enough to act on today.
- Do not overwrite user intent with generic fitness advice.
- Do not treat missing data as evidence.
- Do not store API keys in files.
- Leave generated build outputs, Flutter tool state, iOS Pods, and unrelated
  files alone unless the user explicitly asks for app development work.
