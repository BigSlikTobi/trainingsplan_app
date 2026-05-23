# Agent Setup Guide

Use this file as the first read when a user installs the app and wants to hand
daily coaching to Codex, Claude, Gemini, or another local agent.

The canonical agent instructions now live in the sibling repo:

```text
/Users/tobiaslatta/Projects/temp/t4l-agent-instructions
```

The supported agent transport is the Local LAN Bridge.

## Prerequisites

- Install and open the iOS app once so it can create local training data.
- Install the local bridge package on the computer that will run the agent:

```bash
pipx install /Users/tobiaslatta/Projects/temp/t4l-local-bridge
```

- Grant HealthKit permissions if the user wants recovery, activity, body
  weight, and nutrition signals included in daily context.
- Complete the profile in the app: goal, body metrics, training days, session
  length, equipment, constraints, preferences, and nutrition context.
- Add or review active entries in the Coach tab `Memory Wiki`. These memories
  are durable agent context for goals, constraints, nutrition patterns,
  recovery signals, preferences, and form cues.

## Start The Bridge

Run the bridge on the same computer as the agent:

```bash
t4l-bridge serve --dir ~/CodexFitnessExchange
```

The command prints:

```text
Local URL: http://<local-ip>:8787
Pairing token: 123-456
```

Enter the Local URL and Pairing Token in the app Settings screen, tap
`Connect`, then tap `Push Context`.

If the computer restarts, sleeps, changes network, or the bridge process stops,
restart the bridge and reconnect with the newly printed URL/token.

## Agent Startup Checklist

1. Read the sibling agent instructions repo:
   `/Users/tobiaslatta/Projects/temp/t4l-agent-instructions`.
2. Use the adapter for the current runtime:
   `agents/codex/SKILL.md`, `agents/claude/CLAUDE.md`, or
   `agents/gemini/GEMINI.md`.
3. Verify `t4l-bridge` is installed. If missing, ask the user before installing
   the official local package.
4. Start or reuse the bridge with:
   `t4l-bridge serve --dir ~/CodexFitnessExchange`.
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
   - Give concise food-based nutrition guidance based on today's training,
     yesterday's intake pattern, recovery, preferences, and digestion context.
   - Ask the user before changing direction when goals, constraints, schedule,
     injury notes, or recovery signals conflict.
10. Write app-consumed JSON only through the validated helper scripts whenever a
    helper exists.

## Codex Automation

In Codex, create a daily morning automation that runs against this repository
and uses the Local LAN Bridge exchange folder as the source of truth. The
automation prompt should say:

```text
Read the local T4L agent instructions repo:
/Users/tobiaslatta/Projects/temp/t4l-agent-instructions

Use agents/codex/SKILL.md. Verify or start:
t4l-bridge serve --dir ~/CodexFitnessExchange

Wait for fresh app context from the Local LAN Bridge before coaching. Inspect
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

- Give the agent the local instructions repo and the bridge exchange folder.
- Require it to inspect the exchange files before coaching.
- Require validated writes:
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
