#!/usr/bin/env python3
"""Sync localization keys from en.json into every locale JSON.

- Adds any keys present in en.json but missing elsewhere (English fallback).
- Reports placeholders where value == key.
- Does not overwrite existing non-placeholder translations.

Usage:
  python3 scripts/sync-localization.py
  python3 scripts/sync-localization.py --check   # report only
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "eater" / "Localization"


def load(path: Path) -> dict[str, str]:
  return json.loads(path.read_text(encoding="utf-8"))


def save(path: Path, data: dict[str, str]) -> None:
  ordered = dict(sorted(data.items(), key=lambda kv: kv[0]))
  path.write_text(
    json.dumps(ordered, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
  )


def main() -> int:
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument(
    "--check", action="store_true", help="Report gaps only; do not write files"
  )
  args = parser.parse_args()

  en_path = ROOT / "en.json"
  en = load(en_path)
  locales = sorted(p for p in ROOT.glob("*.json"))

  total_added = 0
  problems = 0

  for path in locales:
    data = load(path)
    missing = sorted(set(en) - set(data))
    placeholders = sorted(k for k, v in data.items() if v == k)

    if path.name != "en.json" and missing and not args.check:
      for key in missing:
        data[key] = en[key]
        total_added += 1
      save(path, data)
      print(f"{path.stem}: added {len(missing)} keys")
    elif missing or placeholders:
      problems += 1
      print(
        f"{path.stem}: missing={len(missing)} placeholders={len(placeholders)}"
      )
      for key in missing[:10]:
        print(f"  + {key}")
      for key in placeholders[:10]:
        print(f"  ! {key}")
    else:
      print(f"{path.stem}: OK ({len(data)} keys)")

  print(f"\nen keys={len(en)} added={total_added} problem_files={problems}")
  return 1 if args.check and problems else 0


if __name__ == "__main__":
  raise SystemExit(main())
