#!/usr/bin/env python3
"""Validate and write a fuel_guidance.json artifact to the app exchange folder."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any


APP_BUNDLE_ID = "com.tobiaslatta.trainingsplanapp"
EXCHANGE_FOLDER = "CodexFitnessExchange"
OUTPUT_FILE = "fuel_guidance.json"
SCHEMA = "fuel_guidance.v1"

VALID_SIGNALS = {"green", "hold", "fuel", "deload"}
VALID_MEAL_IDEA_TAGS = {"pre-training", "post-training", "any-time", "custom"}


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a fuel_guidance.json payload and write it to the "
            "iCloud exchange folder used by the iPhone app."
        )
    )
    parser.add_argument(
        "guidance",
        nargs="?",
        type=Path,
        help="Path to the fuel guidance JSON. Reads stdin when omitted.",
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

    payload = read_payload(args.guidance)
    validate_guidance(payload)

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
        raise SystemExit("Fuel guidance JSON must be an object.")
    return decoded


def validate_guidance(payload: dict[str, Any]) -> None:
    required = [
        "issuedAt",
        "validFor",
        "signal",
        "signalLabel",
        "signalSub",
        "todayAdvice",
        "mealSuggestion",
        "yesterdayRead",
        "mealIdeas",
    ]
    missing = [key for key in required if key not in payload]
    if missing:
        raise SystemExit(f"Missing fuel guidance keys: {', '.join(missing)}")

    signal = payload["signal"]
    if signal not in VALID_SIGNALS:
        raise SystemExit(
            f"signal must be one of {sorted(VALID_SIGNALS)}, got '{signal}'."
        )

    valid_for = payload["validFor"]
    if not isinstance(valid_for, str) or len(valid_for) != 10:
        raise SystemExit("validFor must be a date string in YYYY-MM-DD format.")

    for key in ("signalLabel", "signalSub", "todayAdvice", "yesterdayRead", "issuedAt"):
        if not isinstance(payload[key], str) or not payload[key].strip():
            raise SystemExit(f"'{key}' must be a non-empty string.")

    meal_suggestion = payload["mealSuggestion"]
    if not isinstance(meal_suggestion, dict):
        raise SystemExit("mealSuggestion must be an object.")
    validate_meal_suggestion(meal_suggestion)

    meal_ideas = payload["mealIdeas"]
    if not isinstance(meal_ideas, list):
        raise SystemExit("mealIdeas must be a list.")
    for index, idea in enumerate(meal_ideas, start=1):
        if not isinstance(idea, dict):
            raise SystemExit(f"mealIdeas[{index}] must be an object.")
        validate_meal_idea(idea, index)


def validate_meal_suggestion(suggestion: dict[str, Any]) -> None:
    for key in ("name", "rationale", "timing"):
        if key not in suggestion:
            raise SystemExit(f"mealSuggestion missing required key '{key}'.")
        if not isinstance(suggestion[key], str) or not suggestion[key].strip():
            raise SystemExit(f"mealSuggestion.{key} must be a non-empty string.")


def validate_meal_idea(idea: dict[str, Any], index: int) -> None:
    for key in ("tag", "name", "why"):
        if key not in idea:
            raise SystemExit(f"mealIdeas[{index}] missing required key '{key}'.")
        if not isinstance(idea[key], str) or not idea[key].strip():
            raise SystemExit(f"mealIdeas[{index}].{key} must be a non-empty string.")

    tag = idea["tag"]
    if tag not in VALID_MEAL_IDEA_TAGS:
        raise SystemExit(
            f"mealIdeas[{index}].tag must be one of "
            f"{sorted(VALID_MEAL_IDEA_TAGS)}, got '{tag}'."
        )


def resolve_exchange_dir(override: Path | None) -> Path:
    if override:
        return override.expanduser()

    env_path = os.environ.get("TRAININGSPLAN_EXCHANGE_DIR")
    if env_path:
        return Path(env_path).expanduser()

    mobile_documents = Path.home() / "Library" / "Mobile Documents"
    default = mobile_documents / f"iCloud.{APP_BUNDLE_ID}" / "Documents" / EXCHANGE_FOLDER
    if default.exists():
        return default

    candidates = sorted(mobile_documents.glob(f"iCloud.*/Documents/{EXCHANGE_FOLDER}"))
    guidance_candidates = [path for path in candidates if (path / OUTPUT_FILE).exists()]
    if guidance_candidates:
        return guidance_candidates[0]
    if candidates:
        return candidates[0]

    return default


if __name__ == "__main__":
    raise SystemExit(main())
