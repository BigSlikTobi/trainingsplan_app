#!/usr/bin/env python3
"""Validate and write a Codex nutrition analysis result to the app exchange folder."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any

APP_BUNDLE_ID = "com.example.trainingsplanApp"
EXCHANGE_FOLDER = "CodexFitnessExchange"
OUTPUT_FILE = "nutrition_analysis_result.json"


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a nutrition_analysis_result.json payload and write it to "
            "the iCloud exchange folder used by the iPhone app."
        )
    )
    parser.add_argument("input", nargs="?", type=Path, help="Result JSON to validate.")
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
    if args.input is None:
        parser.error("input is required unless --print-dir is used")

    payload = json.loads(args.input.read_text())
    validate_payload(payload)

    exchange_dir.mkdir(parents=True, exist_ok=True)
    output_path = exchange_dir / OUTPUT_FILE
    tmp_path = exchange_dir / f".{OUTPUT_FILE}.tmp"
    tmp_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n")
    tmp_path.replace(output_path)
    print(output_path)
    return 0


def validate_payload(payload: dict[str, Any]) -> None:
    result = payload.get("result", payload)
    if not isinstance(result, dict):
        raise ValueError("Result payload must be an object.")

    for field in ["calories", "protein", "carbs", "fat"]:
        value = result.get(field)
        if not isinstance(value, int):
            raise ValueError(f"{field} must be an integer.")
        if field == "calories" and value <= 0:
            raise ValueError("calories must be positive.")
        if field != "calories" and value < 0:
            raise ValueError(f"{field} cannot be negative.")

    confidence = result.get("confidence", 0.65)
    if not isinstance(confidence, (int, float)) or confidence < 0 or confidence > 1:
        raise ValueError("confidence must be a number from 0 to 1.")

    if "assumptions" in result and not isinstance(result["assumptions"], list):
        raise ValueError("assumptions must be a list of strings.")

    target = result.get("target") or result.get("nutritionTarget")
    if target is not None:
        if not isinstance(target, dict):
            raise ValueError("target must be an object.")
        if not isinstance(target.get("dailyCalories"), int):
            raise ValueError("target.dailyCalories must be an integer.")


def resolve_exchange_dir(override: Path | None) -> Path:
    if override is not None:
        return override.expanduser().resolve()

    env = os.environ.get("TRAININGSPLAN_EXCHANGE_DIR")
    if env:
        return Path(env).expanduser().resolve()

    home = Path.home()
    mobile_documents = home / "Library" / "Mobile Documents"
    default = mobile_documents / f"iCloud.{APP_BUNDLE_ID}" / "Documents" / EXCHANGE_FOLDER
    if default.exists():
        return default

    candidates = sorted(mobile_documents.glob(f"iCloud.*/Documents/{EXCHANGE_FOLDER}"))
    if candidates:
        return candidates[0]

    return default


if __name__ == "__main__":
    raise SystemExit(main())
