#!/usr/bin/env python3
"""Validate and write a next_day_plan.json payload to the app exchange folder."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any


APP_BUNDLE_ID = "com.tobiaslatta.trainingsplanapp"
EXCHANGE_FOLDER = "CodexFitnessExchange"
OUTPUT_FILE = "next_day_plan.json"


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a next_day_plan.json payload and write it to the "
            "iCloud exchange folder used by the iPhone app."
        )
    )
    parser.add_argument(
        "plan",
        nargs="?",
        type=Path,
        help="Path to the next-day plan JSON. Reads stdin when omitted.",
    )
    parser.add_argument(
        "--exchange-dir",
        type=Path,
        help="Override the exchange folder path.",
    )
    parser.add_argument(
        "--print-dir",
        action="store_true",
        help="Print the resolved exchange folder and exit.",
    )
    args = parser.parse_args()

    exchange_dir = resolve_exchange_dir(args.exchange_dir)
    if args.print_dir:
        print(exchange_dir)
        return 0

    payload = read_payload(args.plan)
    workout = extract_workout(payload)
    validate_workout(workout)

    exchange_dir.mkdir(parents=True, exist_ok=True)
    output_path = exchange_dir / OUTPUT_FILE
    tmp_path = exchange_dir / f".{OUTPUT_FILE}.tmp"
    tmp_path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    tmp_path.replace(output_path)
    print(output_path)
    return 0


def read_payload(path: Path | None) -> dict[str, Any]:
    raw = path.read_text(encoding="utf-8") if path else os.sys.stdin.read()
    try:
        decoded = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON: {exc}") from exc
    if not isinstance(decoded, dict):
        raise SystemExit("Next-day plan JSON must be an object.")
    return decoded


def extract_workout(payload: dict[str, Any]) -> dict[str, Any]:
    workout = payload.get("workout", payload)
    if not isinstance(workout, dict):
        raise SystemExit("Plan must be either a workout object or {'workout': {...}}.")
    return workout


def validate_workout(workout: dict[str, Any]) -> None:
    required = [
        "id",
        "week",
        "day",
        "title",
        "focus",
        "rationale",
        "exercises",
        "conditioning",
    ]
    missing = [key for key in required if key not in workout]
    if missing:
        raise SystemExit(f"Workout missing keys: {', '.join(missing)}")

    exercises = workout["exercises"]
    if not isinstance(exercises, list) or not exercises:
        raise SystemExit("Workout exercises must be a non-empty list.")

    for exercise_index, exercise in enumerate(exercises, start=1):
        if not isinstance(exercise, dict):
            raise SystemExit(f"Exercise {exercise_index} must be an object.")
        missing = [
            key
            for key in [
                "exerciseId",
                "name",
                "sets",
                "reps",
                "targetLoad",
                "targetRpe",
                "restSeconds",
                "coachCue",
            ]
            if key not in exercise
        ]
        if missing:
            raise SystemExit(
                f"Exercise {exercise_index} missing keys: {', '.join(missing)}"
            )
        for optional_key in ["loadLabel", "primaryCue", "detailNote", "warningCue"]:
            if optional_key in exercise and not isinstance(exercise[optional_key], str):
                raise SystemExit(
                    f"Exercise {exercise_index} {optional_key} must be a string."
                )
        validate_exercise_media(exercise, exercise_index)


def validate_exercise_media(exercise: dict[str, Any], exercise_index: int) -> None:
    media = exercise.get("media")
    if media is None:
        return
    if not isinstance(media, dict):
        raise SystemExit(f"Exercise {exercise_index} media must be an object.")

    for key in ["explainerUrl", "youtubeUrl", "videoUrl", "setup"]:
        if key in media and not isinstance(media[key], str):
            raise SystemExit(f"Exercise {exercise_index} media.{key} must be a string.")

    for key in ["cues", "commonMistakes"]:
        if key not in media:
            continue
        if not isinstance(media[key], list) or not all(
            isinstance(item, str) for item in media[key]
        ):
            raise SystemExit(
                f"Exercise {exercise_index} media.{key} must be a list of strings."
            )


def resolve_exchange_dir(override: Path | None) -> Path:
    if override:
        return override.expanduser()

    env_path = os.environ.get("TRAININGSPLAN_EXCHANGE_DIR")
    if env_path:
        return Path(env_path).expanduser()

    mobile_documents = Path.home() / "Library" / "Mobile Documents"
    default = mobile_documents / f"iCloud.{APP_BUNDLE_ID}" / "Documents" / EXCHANGE_FOLDER
    tilde_container = "iCloud~" + APP_BUNDLE_ID.replace(".", "~")
    tilde_default = mobile_documents / tilde_container / "Documents" / EXCHANGE_FOLDER
    if default.exists():
        return default
    if tilde_default.exists():
        return tilde_default

    candidates = sorted(mobile_documents.glob(f"iCloud*/Documents/{EXCHANGE_FOLDER}"))
    plan_candidates = [path for path in candidates if (path / OUTPUT_FILE).exists()]
    if plan_candidates:
        return plan_candidates[0]
    if candidates:
        return candidates[0]

    return default


if __name__ == "__main__":
    raise SystemExit(main())
