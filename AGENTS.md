# AGENTS.md

## Project Overview

This is a Flutter iOS app for creating home training plans. The app is named
`trainingsplan_app` in `pubspec.yaml` and presents itself as Codex Fitness Coach
in the UI.

The app can generate training plans locally or through the OpenAI Responses API.
It also supports an agent coaching workflow by exchanging JSON files through an
iCloud folder. For user installation and daily agent handoff, read
`docs/setup.md` first, then `docs/codex_coach_workflow.md`.

## Repository Notes

- This directory may not be inside a Git repository. Do not assume git history,
  branches, or diffs are available.
- Do not commit or hardcode OpenAI API keys.
- Build outputs, Flutter tool state, iOS Pods, and other generated files should
  generally be left alone unless the task explicitly requires them.

## Common Commands

Run checks before handing off code changes when feasible:

```bash
flutter analyze
flutter test
```

Run the app with OpenAI enabled:

```bash
flutter run \
  --dart-define=OPENAI_API_KEY=sk-your-key \
  --dart-define=OPENAI_MODEL=gpt-5.2
```

`OPENAI_MODEL` is optional. The app defaults to `gpt-5.2`.

## Project Structure

- `lib/main.dart`: Flutter entrypoint.
- `lib/src/app.dart`: Material app shell, theme, and `FitnessScope`.
- `lib/src/ui/dashboard.dart`: Main user interface.
- `lib/src/state/fitness_controller.dart`: App state controller.
- `lib/src/models/fitness_models.dart`: Fitness domain models.
- `lib/src/data/`: Local store, seed data, and exercise library.
- `lib/src/services/`: OpenAI coaching exchange, health sync, media capture,
  and iCloud exchange directory services.
- `tools/write_training_block_plan.py`: Helper for validating and writing a
  Codex-generated `training_block_plan.json`.
- `docs/setup.md`: first-read setup and daily agent handoff guide.
- `docs/codex_coach_workflow.md`: JSON exchange workflow and schema contract.

## Coding Guidelines

- Follow existing Flutter and Dart style.
- Keep changes narrowly scoped to the requested behavior.
- Prefer existing models, controller methods, and service boundaries over adding
  new abstractions.
- Use `flutter_lints` expectations from `analysis_options.yaml`.
- Add or update tests for behavior changes, especially controller logic,
  parsing/import behavior, and UI navigation expectations.
- Keep user-facing text consistent with the app's current German/English mix
  unless the task asks for localization cleanup.

## Design Guidelines

- The app uses Material 3 with a restrained fitness-studio palette:
  - ink: `0xFF18201B`
  - paper: `0xFFF8F6F0`
  - moss: `0xFF526B54`
  - coral: `0xFFCB6B52`
- Cards use low elevation, white surfaces, 8px radius, and subtle borders.
- Prefer dense, functional mobile UI over marketing-style layouts.
- Preserve iOS-oriented behavior and permissions where relevant.

## Codex Coaching Workflow

Full setup and daily processing guidance lives in `docs/setup.md` and
`docs/codex_coach_workflow.md`.

When working with exported training block requests:

1. Read `training_block_request.json` and `athlete_profile.json` from the
   exchange folder.
2. Discuss the training goal, schedule, equipment, constraints, and measurable
   target before writing final JSON.
3. Write the final plan using:

```bash
python3 tools/write_training_block_plan.py plan.json
```

The helper validates the minimum schema and writes `training_block_plan.json`
atomically to the exchange folder. Use:

```bash
python3 tools/write_training_block_plan.py --print-dir
```

to inspect the resolved exchange directory.
