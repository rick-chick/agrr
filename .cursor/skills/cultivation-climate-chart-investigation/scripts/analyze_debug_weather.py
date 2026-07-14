#!/usr/bin/env python3
"""Summarize agrr weather JSON under tmp/debug (gaps, prediction meta, optional cultivation window)."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import date, datetime
from pathlib import Path


def parse_date(value: str) -> date:
    return datetime.strptime(value[:10], "%Y-%m-%d").date()


def load_data(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def series_dates(payload: dict) -> list[date]:
    rows = payload.get("data") or []
    out: list[date] = []
    for row in rows:
        time_value = row.get("time") or row.get("date")
        if time_value:
            out.append(parse_date(str(time_value)))
    return sorted(out)


def find_gaps(dates: list[date]) -> list[tuple[date, date, int]]:
    gaps: list[tuple[date, date, int]] = []
    for index in range(1, len(dates)):
        delta = (dates[index] - dates[index - 1]).days
        if delta > 1:
            gaps.append((dates[index - 1], dates[index], delta - 1))
    return gaps


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("weather_json", type=Path, help="e.g. tmp/debug/progress_weather_<ts>.json")
    parser.add_argument("--start-date", dest="start_date", help="cultivation start (YYYY-MM-DD)")
    parser.add_argument("--completion-date", dest="completion_date", help="cultivation completion")
    args = parser.parse_args()

    if not args.weather_json.is_file():
        print(f"ERROR: not found: {args.weather_json}", file=sys.stderr)
        return 1

    payload = load_data(args.weather_json)
    dates = series_dates(payload)
    if not dates:
        print("ERROR: no daily rows in data[]", file=sys.stderr)
        return 1

    print(f"file: {args.weather_json}")
    print(f"rows: {len(dates)}  range: {dates[0]} .. {dates[-1]}")
    for key in (
        "prediction_start_date",
        "prediction_end_date",
        "target_end_date",
        "generated_at",
        "predicted_at",
        "model",
    ):
        if key in payload:
            print(f"  {key}: {payload[key]}")

    gaps = find_gaps(dates)
    print(f"gaps (>1 day): {len(gaps)}")
    for left, right, missing in gaps[:5]:
        print(f"  {left} -> {right} ({missing} missing days)")
    if len(gaps) > 5:
        print(f"  ... and {len(gaps) - 5} more")

    if args.start_date:
        start = parse_date(args.start_date)
        in_window = [d for d in dates if d >= start]
        print(f"from cultivation start {start}:")
        if in_window:
            print(f"  first day: {in_window[0]}  count: {len(in_window)}")
        else:
            print("  WARNING: no rows on or after start_date")

    if args.start_date and args.completion_date:
        start = parse_date(args.start_date)
        completion = parse_date(args.completion_date)
        window = [d for d in dates if start <= d <= completion]
        print(f"cultivation window [{start} .. {completion}]: {len(window)} days")
        if window:
            print(f"  coverage: {window[0]} .. {window[-1]}")
            expected = (completion - start).days + 1
            if len(window) < expected:
                print(f"  WARNING: expected up to {expected} calendar days, have {len(window)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
