# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter iOS app (`trainingsplan_app`, UI name "Codex Fitness Coach" / "T4L Trainer") for generating home training plans. Plans can be produced locally or via the OpenAI Responses API, and exchanged with a Codex, Claude, or other agent session through JSON files in an iCloud folder.

For user installation, daily coaching setup, and agent handoff, read `docs/setup.md` first, then `docs/codex_coach_workflow.md`.

This directory may not be inside a Git repository — do not assume git history is available.

## Commands

```bash
flutter analyze
flutter test
flutter test test/fitness_controller_test.dart            # single test file
flutter test --plain-name "imports codex plan"            # single test by name
```

Run app with OpenAI enabled (key is optional; local generator is the fallback):

```bash
flutter run \
  --dart-define=OPENAI_API_KEY=sk-your-key \
  --dart-define=OPENAI_MODEL=gpt-5.2
```

For Xcode builds, pass the same `--dart-define` flags as Flutter build arguments. Never commit a key.

Codex-side helpers (write JSON into the iCloud exchange folder):

```bash
python3 tools/write_training_block_plan.py plan.json
python3 tools/write_training_block_plan.py --print-dir       # show resolved exchange dir
python3 tools/write_next_day_plan.py plan.json
python3 tools/write_nutrition_analysis_result.py result.json
TRAININGSPLAN_EXCHANGE_DIR=/abs/path python3 tools/write_training_block_plan.py plan.json   # override location
```

## Architecture

Single-page Material 3 app rooted at `lib/main.dart` → `lib/src/app.dart`. State flows through one controller; UI is one large dashboard widget. There is no router and no DI framework.

- `lib/src/state/fitness_controller.dart` — the single `ChangeNotifier` owning all app state (training blocks, workouts, logs, nutrition, profile). Exposed app-wide through `FitnessScope` (InheritedNotifier in `app.dart`). New behavior almost always belongs here, not in new abstractions.
- `lib/src/models/fitness_models.dart` — all domain models (`TrainingBlock`, `Workout`, `Exercise`, nutrition entities) with `toJson`/`fromJson`. The JSON shape here is the contract for both the Codex exchange files and the OpenAI Responses API output.
- `lib/src/data/` — `local_store.dart` (Drift/SQLite persistence) and `seed_data.dart` exposing `createEmptyFitnessData()`. The app has **no local block templates** — first launch is an empty shell and all training blocks come from the agent via the Codex JSON exchange.
- `lib/src/services/`
  - `coach_exchange_service.dart` — watches iCloud exchange dir, parses `training_block_plan.json` and `nutrition_analysis_result.json`, surfaces "new block available" prompts.
  - `exchange_directory_service.dart` — resolves iOS ubiquity container path `Documents/CodexFitnessExchange`.
  - `health_sync_service.dart` — HealthKit reads/writes (workouts, bodyweight, nutrition). Nutrition is only written after the user accepts a Codex analysis.
  - `media_capture_service.dart` — `image_picker` wrapper for meal photos.
- `lib/src/ui/dashboard.dart` — main UI. Multiple tabs (Blocks, Workout, Ernaehrung, etc.) all built from controller state.

### Codex JSON exchange (critical contract)

The desktop ↔ app handoff is **file-based JSON in an iCloud folder**, not an API. Three flows:

1. **Daily next-day plan, default**: app exports `day_context.json` + `daily_snapshot.json` → Codex writes exactly one `next_day_plan.json` containing a single `workout` object through `python3 tools/write_next_day_plan.py plan.json` → app imports it into the active block. Do not write `training_block_plan.json` for daily coaching.
2. **Training block, explicit full-block request only**: app exports `training_block_request.json` + `athlete_profile.json` → Codex writes `training_block_plan.json` → app imports as active block. Schema is enforced both by `tools/write_training_block_plan.py` and by parsing in `coach_exchange_service.dart` / `fitness_models.dart`. Valid `style`: `rugby`, `boxer`, `hybrid`, `strengthHypertrophy`, `conditioning`, `custom`.
3. **Nutrition**: app writes `nutrition_analysis_request.json` (+ image into `meal_images/`) → Codex writes `nutrition_analysis_result.json` → app shows result for review → on accept, persists locally + HealthKit. Required result fields: `calories` (positive), `protein/carbs/fat` (non-negative ints), optional `confidence` (0–1). Codex (not the app) infers the calorie target for this workflow.

For both `next_day_plan.json` and `training_block_plan.json`, workouts require `id, week, day, title, focus, rationale, conditioning, exercises[]`; exercises require `exerciseId, name, sets, reps, targetLoad, targetRpe, restSeconds, coachCue` plus optional mobile fields `loadLabel`, `primaryCue`, `detailNote`, `warningCue`, and optional `media{ setup, cues[], commonMistakes[], explainerUrl|youtubeUrl|videoUrl }`. When generating plans, keep `targetLoad` and `coachCue` complete for logs, use `loadLabel` and `primaryCue` for compact phone display, and move longer guidance into `detailNote` or `media`.

Full schema lives in `docs/codex_coach_workflow.md`. When changing model fields, update *all four* sites: model class, Python helper validator, exchange-service parser, and the doc.

## Conventions

- Material 3 with restrained palette: ink `0xFF18201B`, paper `0xFFF8F6F0`, moss `0xFF526B54`, coral `0xFFCB6B52`. Cards: low elevation, white surfaces, 8px radius, subtle borders. Prefer dense functional UI over marketing layouts.
- User-facing text is intentionally a German/English mix — don't "fix" it to one language unless asked.
- Prefer extending existing controller methods and service boundaries over introducing new abstractions.
- iOS-only target; preserve iOS permissions/behavior (HealthKit, iCloud ubiquity, photo library).
- Lints from `analysis_options.yaml` (`flutter_lints`). Run `flutter analyze` before handing off.
