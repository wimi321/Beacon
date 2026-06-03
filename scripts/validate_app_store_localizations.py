#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
GENERATOR = ROOT / "scripts/generate_app_store_localizations.py"


def load_generator():
    spec = importlib.util.spec_from_file_location("app_store_generator", GENERATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {GENERATOR}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Beacon App Store localization package.")
    parser.add_argument("--screenshots", action="store_true", help="Also validate generated screenshot files.")
    parser.add_argument("--locale", action="append", help="Limit screenshot validation to an app or Apple locale code. Repeatable.")
    args = parser.parse_args()

    generator = load_generator()
    errors = generator.validate_metadata()
    if args.screenshots:
        errors.extend(generator.validate_screenshots(set(args.locale) if args.locale else None))

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("App Store localization validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
