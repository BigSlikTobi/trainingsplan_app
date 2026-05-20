# Agent Coach Workflow

Use this workflow when the training plan or daily coaching is handled by Codex,
Claude, or another agent and then exchanged with the iPhone app through iCloud.
The app UI still uses Codex wording in several places, and the JSON file names
remain unchanged.

## Conversation flow

1. In the agent session, discuss the plan brief before writing JSON. Clarify at least:
   - sport or goal, for example American Football, mountain climbing, boxing, hypertrophy, conditioning
   - available training days and session length
   - equipment and space
   - injury constraints or movements to avoid
   - measurable target for the block
2. The agent writes `training_block_plan.json` to the iCloud exchange folder.
3. The iPhone app checks the exchange folder while open and when it returns to the foreground.
4. When a plan is present, the app shows `Neuer Codex Trainingsblock verfuegbar`.
5. Tap `Import` to make the new block active.

## Exchange folder

On iPhone, the app asks iOS for its iCloud ubiquity container and uses:

```text
Documents/CodexFitnessExchange
```

From the Mac, the helper resolves the likely iCloud location automatically. You can also override it:

```bash
TRAININGSPLAN_EXCHANGE_DIR="/absolute/path/to/CodexFitnessExchange" \
  python3 tools/write_training_block_plan.py plan.json
```

To see the resolved folder:

```bash
python3 tools/write_training_block_plan.py --print-dir
```

Use this printed path as the canonical exchange folder. If another helper
resolves a different folder on a local machine, pass the canonical path with
`--exchange-dir` or `TRAININGSPLAN_EXCHANGE_DIR`.

## Output contract

The app imports either a raw `TrainingBlock` object or:

```json
{
  "block": {
    "id": "block_american_football_2026_05",
    "style": "custom",
    "title": "8 Wochen American Football Athletik",
    "durationWeeks": 8,
    "currentWeek": 1,
    "weeklyFocus": [],
    "measurableTargets": [],
    "workouts": [],
    "createdBy": "Codex",
    "createdAt": "2026-05-19T10:00:00+02:00"
  }
}
```

Valid `style` values are `rugby`, `boxer`, `hybrid`, `strengthHypertrophy`, `conditioning`, and `custom`.

Each workout must include `id`, `week`, `day`, `title`, `focus`, `rationale`, `conditioning`, and a non-empty `exercises` list. Each exercise must include `exerciseId`, `name`, `sets`, `reps`, `targetLoad`, `targetRpe`, `restSeconds`, and `coachCue`.

Exercises may also include a `media` object. The app uses this to populate the
expanded `Cues und Fehler` section for Codex-imported plans. Imported exercises
do not fall back to the built-in exercise library at render time. Include
`setup`, `cues`, and `commonMistakes` to show that section. Include
`explainerUrl`, `youtubeUrl`, or `videoUrl` to enable the play button.

```json
{
  "exerciseId": "goblet_squat",
  "name": "Goblet Squat",
  "sets": 3,
  "reps": "8-10",
  "targetLoad": "24 kg",
  "targetRpe": 7.5,
  "restSeconds": 90,
  "coachCue": "Brace before each rep.",
  "media": {
    "youtubeUrl": "https://www.youtube.com/watch?v=example",
    "setup": "Kettlebell tight to sternum, feet rooted.",
    "cues": ["Tripod foot", "Ribs down", "Drive evenly through both feet"],
    "commonMistakes": ["Losing heel pressure", "Knees collapsing inward"]
  }
}
```

## Agent-side write command

After drafting a plan JSON:

```bash
python3 tools/write_training_block_plan.py plan.json
```

The helper validates the minimum app schema and atomically writes:

```text
training_block_plan.json
```

The iPhone app then imports that file as the active training block.

## Agent behavior rules

- Read the available exchange files before coaching. Do not rely on memory from
  a previous chat if the current files disagree.
- Treat explicit user goals, constraints, injury notes, equipment limits, and
  schedule limits as higher priority than generic training advice.
- Separate facts from assumptions in the response. Missing HealthKit metrics,
  missing nutrition logs, and omitted JSON fields are unknown, not zero.
- Ask the user before changing the block goal, replacing a training day with a
  different modality, ignoring a constraint, or making a recommendation from
  stale context.
- Keep recommendations actionable: what to train today, what intensity to use,
  what to watch technically, and what food guidance fits today.
- Write app-consumed JSON only through the validated helper scripts when a
  helper exists.

## Memory wiki

The app keeps a local `memoryWiki` of durable coaching context. Entries are
human-editable in the Coach tab and are exported to agents as compact structured
facts plus optional markdown detail. The app does not import memory changes from
the agent in v1.

The agent receives the primary daily coaching context in `day_context.json`, active
memories in `daily_snapshot.json`, and nutrition-relevant memories in
`nutrition_analysis_request.json`:

```json
{
  "memoryWiki": {
    "schema": "memory_wiki.v1",
    "entryCount": 2,
    "entries": [
      {
        "category": "form",
        "title": "Goblet squat cue",
        "summary": "User needs reminders to keep heel pressure.",
        "markdown": "Captured from workout notes.",
        "source": "auto_workout",
        "confidence": 0.78,
        "updatedAt": "2026-05-20T09:00:00+02:00"
      }
    ],
    "byCategory": {
      "form": []
    },
    "instructions": "Use these active memories as durable coaching context."
  }
}
```

Valid memory categories are `training`, `form`, `nutrition`, `recovery`,
`preference`, `constraint`, and `goal`. Use recent, high-confidence entries as
stable context when adjusting plans, cues, nutrition targets, and next-day
recommendations.

Use the categories this way:

- `goal`: long-term outcome, current block purpose, measurable targets, and
  short-term focus for the next days.
- `constraint`: injuries, movements to avoid, schedule limits, available space,
  equipment limits, and hard user boundaries.
- `preference`: coaching language, exercise likes/dislikes, session style,
  feedback style, and practical habits that improve adherence.
- `training`: performance patterns, load tolerance, volume response, exercise
  substitutions that worked, and sessions that caused unusual fatigue.
- `form`: technical cues, recurring mistakes, setup details, and exercise
  instructions that should be repeated in future workouts.
- `nutrition`: food patterns, meal timing, protein/carb/fat balance, digestion,
  hydration, bodyweight trend notes, and foods or routines that affect the goal.
- `recovery`: readiness, soreness, sleep, stress, outside activity, and signals
  that should affect intensity or exercise selection.

When multiple memories conflict, prefer active, recent, high-confidence entries.
If a low-confidence memory would materially change training or nutrition, flag
it as an assumption and ask the user to confirm.

## Daily context workflow

`day_context.json` is the primary snapshot for agent coaching. The app writes it
only on explicit pushes: after workout completion, before sending a meal analysis
request, and when the user manually exports the daily context. There is no
background polling or hidden sync loop.

The context uses the device-local calendar day, from local midnight to the next
local midnight. Training logs and nutrition logs stay separate in the app data,
but the export summarizes them together with Apple Health activity so the agent
can reason about the full day.

The file uses schema `day_context.v1` and includes:

- `dayKey`, `timezoneOffset`, `windowStart`, `windowEnd`, and `generatedAt`.
- `activitySummary` from HealthKit, including available daily totals such as
  steps, active energy, exercise minutes, move time, walking/running distance,
  cycling distance, flights climbed, heart-rate signals, blood oxygen, sleep,
  body weight, and dietary totals.
- `activitySessions`, including Apple Health workout sessions such as walks,
  runs, bike rides, and other workouts even when they were not planned inside
  the app.
- `trainingLogs`, `nutritionLogs`, `latestWorkoutLog`, `latestNutrition`,
  profile, active block, next workout, and memory wiki.

When adapting tomorrow's training or today's nutrition, consider post-training
walks, runs, rides, and other Apple Fitness activity as recovery and energy-load
signals. Missing HealthKit permissions or unavailable metrics are represented in
`activitySummary.readStatus` and optional `missingPermissions`; omitted metrics
must not be treated as zero.

## Daily coaching loop

Use this loop for the default morning planning workflow:

1. Resolve the exchange folder and inspect the current files. Prioritize
   `day_context.json`, then use `daily_snapshot.json`, `athlete_profile.json`,
   `training_block_request.json`, and `nutrition_analysis_request.json` as
   supporting context when present.
2. Read the profile, active block, next workout, latest workout log, recent
   workout logs, latest nutrition, recent nutrition logs, HealthKit
   `activitySummary`, `activitySessions`, and active `memoryWiki`.
3. Identify the day's coaching facts:
   - long-term goal and current block target
   - current week and next workout
   - last days' performance, readiness, soreness, and notable set/RPE patterns
   - today's and recent activity load from Apple Health
   - nutrition context, yesterday's intake pattern, and bodyweight signal
   - relevant active memories by category
4. Identify assumptions separately. Stale context, missing HealthKit
   permissions, missing logs, and absent nutrition entries should be stated as
   unknowns.
5. Decide the training action for today:
   - `progress`: performance and recovery support a planned increase.
   - `hold`: keep the plan as written because signals are neutral or uncertain.
   - `substitute`: keep the intent but change movements for equipment,
     soreness, pain, or schedule.
   - `deload`: reduce load, volume, density, or intensity because fatigue or
     recovery signals are poor.
   - `rest`: skip planned training when recovery, pain, illness, or schedule
     constraints make training inappropriate.
6. Give food-based nutrition guidance for today from the goal, body metrics,
   active block, yesterday's intake pattern, training load, recovery, and known
   preferences. Do not set fixed targets unless the user asks for them.
7. If the user asks for an app-importable training block, write
   `training_block_plan.json` through
   `python3 tools/write_training_block_plan.py plan.json`.
8. If the user exports a meal analysis request, write
   `nutrition_analysis_result.json` through
   `python3 tools/write_nutrition_analysis_result.py --exchange-dir
   "/absolute/path/to/CodexFitnessExchange" result.json`.

## Nutrition analysis workflow

The app can export a meal for agent nutrition analysis through the same iCloud
exchange folder.

1. In the app, open `Ernaehrung`, edit the nutrition profile if body metrics are
   stale, then tap `Meal analysieren`.
2. Enter a meal description, attach a photo from the library or camera, and send
   it to Codex.
3. The app writes `nutrition_analysis_request.json` and, when present, copies
   the image into `meal_images/`.
4. The agent reviews the request, `day_context.json`, the active training block,
   next workout, latest workout log, recent workout logs, recent nutrition logs,
   and profile body metrics.
5. The agent writes `nutrition_analysis_result.json`.
6. The app imports the result, shows calories/macros/confidence/assumptions for
   review, and writes to local nutrition plus HealthKit only after acceptance.

The request includes instructions for the agent to infer the calorie target from
the training goal, current training status, recent intake, bodyweight trend,
height, weight, age, sex, training days, and session length. The app does not
calculate this target locally for the agent workflow.

### Nutrition result contract

The app imports either a raw result object or:

```json
{
  "schema": "nutrition_analysis_result.v1",
  "result": {
    "id": "meal_result_2026_05_19_lunch",
    "requestId": "meal_request_123",
    "analyzedAt": "2026-05-19T13:00:00+02:00",
    "mealDescription": "Rice bowl with chicken, avocado, vegetables, and sauce",
    "calories": 780,
    "protein": 48,
    "carbs": 82,
    "fat": 28,
    "bodyWeightKg": 82.0,
    "confidence": 0.72,
    "assumptions": [
      "Rice portion estimated at 250 g cooked",
      "Sauce estimated at 2 tablespoons"
    ],
    "rationale": "Fits a training-day lunch with high protein and moderate carbs.",
    "correctionNotes": "Adjust sauce or rice amount if the photo underestimates portions.",
    "target": {
      "dailyCalories": 2750,
      "protein": 175,
      "carbs": 320,
      "fat": 80,
      "goalMode": "Codex inferred recomposition",
      "rationale": "Recent training volume is high and intake trend is near maintenance.",
      "updatedAt": "2026-05-19T13:00:00+02:00",
      "source": "Codex"
    }
  }
}
```

Required nutrition result fields are `calories`, `protein`, `carbs`, and `fat`.
`calories` must be positive. Macro values must be non-negative integers.
`confidence` is optional but should be a number from `0` to `1`.

After drafting a nutrition result JSON:

```bash
python3 tools/write_nutrition_analysis_result.py \
  --exchange-dir "/absolute/path/to/CodexFitnessExchange" \
  result.json
```

The helper validates the minimum app schema and atomically writes:

```text
nutrition_analysis_result.json
```

## Fuel guidance workflow

The app's Nutrition tab renders signal-based fuel guidance authored by the
agent. This keeps coaching content out of the app binary and lets the agent
use the full day context — training block, body metrics, recent logs,
preferences, and equipment — to generate actionable advice.

### Artifact schema

```json
{
  "schema": "fuel_guidance.v1",
  "issuedAt": "2026-05-20T07:00:00+02:00",
  "validFor": "2026-05-20",
  "signal": "green",
  "signalLabel": "GREEN LIGHT",
  "signalSub": "Fuel und Readiness im Einklang — heute Vollgas.",
  "todayAdvice": "Protein ist heute der Hebel — 30–40g pro Hauptmahlzeit. ...",
  "mealSuggestion": {
    "name": "Spaghetti Carbonara",
    "rationale": "Pasta füllt Glykogen, Eier und Guanciale liefern Protein...",
    "timing": "post-training"
  },
  "yesterdayRead": "Solide Basis — passt zum heutigen Krafttraining.",
  "mealIdeas": [
    { "tag": "pre-training",  "name": "...", "why": "..." },
    { "tag": "post-training", "name": "...", "why": "..." },
    { "tag": "any-time",      "name": "...", "why": "..." }
  ]
}
```

**Required fields:** `issuedAt`, `validFor`, `signal`, `signalLabel`,
`signalSub`, `todayAdvice`, `mealSuggestion` (with `name`, `rationale`,
`timing`), `yesterdayRead`, `mealIdeas`.

**Valid `signal` values:** `green`, `hold`, `fuel`, `deload`.

**Valid `mealIdeas[].tag` values:** `pre-training`, `post-training`,
`any-time`, `custom`.

`validFor` must be a date string in `YYYY-MM-DD` format matching the
device-local calendar day for which the guidance applies. The app shows a
neutral fallback state ("Warte auf Fuel Guidance vom Coach") when no
guidance is present or when `validFor` is older than today.

### Agent-side write command

```bash
python3 tools/write_fuel_guidance.py guidance.json
```

Or override the exchange directory:

```bash
TRAININGSPLAN_EXCHANGE_DIR="/absolute/path/to/CodexFitnessExchange" \
  python3 tools/write_fuel_guidance.py guidance.json
```

To inspect the resolved folder:

```bash
python3 tools/write_fuel_guidance.py --print-dir
```

The helper validates the schema, hard-fails with a clear error on invalid
input, and atomically writes:

```text
fuel_guidance.json
```

### How the app reacts

1. On foreground and on `load()`, `checkForCodexUpdates()` checks whether
   `fuel_guidance.json` is present in the exchange folder.
2. If present, the file is parsed into `FuelGuidance`, stored in
   `FitnessData.fuelGuidance`, persisted locally, and the exchange file is
   deleted.
3. The Nutrition tab checks `validFor` against today's date. If the guidance
   is fresh, the signal badge, Today's Fuel card, Yesterday's Signal card,
   and Meal Ideas section all render from the guidance. If the guidance is
   absent or stale, a muted placeholder is shown in place of those sections.
4. The Meal Analysis section at the bottom of the tab is independent and
   always shown regardless of fuel guidance state.
