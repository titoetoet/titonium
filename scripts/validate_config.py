#!/usr/bin/env python3
"""Validate the small shipped contract consumed by the protected skeleton."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_SETTINGS_KEYS = {
    "$schema", "schemaVersion", "locale", "appearance", "accessibility", "applications", "modules"
}
REQUIRED_TRANSLATION_PREFIXES = (
    "application.error.", "clipboard.error.", "menubar.clock.",
    "menubar.input_method.", "menubar.workspace.", "spotlight.",
)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"{path}: invalid JSON: {error}") from error


def validate_settings(data: Any) -> list[str]:
    if not isinstance(data, dict):
        return ["settings must be an object"]
    errors: list[str] = []
    if set(data) != REQUIRED_SETTINGS_KEYS:
        errors.append("settings keys do not match the protected contract")
    if data.get("$schema") != "titonium.settings/v5" or data.get("schemaVersion") != 5:
        errors.append("settings schema must be titonium.settings/v5")
    if data.get("locale") not in {"vi", "en"}:
        errors.append("locale must be vi or en")

    appearance = data.get("appearance")
    if not isinstance(appearance, dict) or set(appearance) != {"mode"}:
        errors.append("appearance must contain only mode")
    elif appearance.get("mode") not in {"dark", "light"}:
        errors.append("appearance.mode must be dark or light")

    accessibility = data.get("accessibility")
    if not isinstance(accessibility, dict) or set(accessibility) != {"reducedMotion"}:
        errors.append("accessibility must contain only reducedMotion")
    elif not isinstance(accessibility.get("reducedMotion"), bool):
        errors.append("accessibility.reducedMotion must be a boolean")

    applications = data.get("applications")
    if not isinstance(applications, dict) or set(applications) != {"hiddenIds"}:
        errors.append("applications must contain only hiddenIds")
    else:
        hidden_ids = applications.get("hiddenIds")
        if not isinstance(hidden_ids, list):
            errors.append("applications.hiddenIds must be an array")
        elif any(not isinstance(entry, str) or not entry for entry in hidden_ids):
            errors.append("applications.hiddenIds must contain non-empty strings")
        elif len(hidden_ids) != len(set(hidden_ids)):
            errors.append("applications.hiddenIds must be unique")

    modules = data.get("modules")
    if not isinstance(modules, dict) or set(modules) != {"spotlight", "clock"}:
        errors.append("modules must contain only spotlight and clock")
        return errors
    spotlight = modules.get("spotlight")
    if not isinstance(spotlight, dict) or set(spotlight) != {"pageTransition", "transitionDuration"}:
        errors.append("modules.spotlight has an invalid shape")
    else:
        if spotlight.get("pageTransition") not in {"none", "fade", "slide-fade"}:
            errors.append("modules.spotlight.pageTransition is invalid")
        duration = spotlight.get("transitionDuration")
        if not isinstance(duration, int) or isinstance(duration, bool) or not 0 <= duration <= 500:
            errors.append("modules.spotlight.transitionDuration must be an integer from 0 to 500")
    clock = modules.get("clock")
    if not isinstance(clock, dict) or set(clock) != {"use24Hour"}:
        errors.append("modules.clock must contain only use24Hour")
    elif not isinstance(clock.get("use24Hour"), bool):
        errors.append("modules.clock.use24Hour must be a boolean")
    return errors


def validate_locale(data: Any, expected_locale: str) -> list[str]:
    if not isinstance(data, dict):
        return ["locale document must be an object"]
    errors: list[str] = []
    if data.get("schemaVersion") != 1 or data.get("locale") != expected_locale:
        errors.append(f"locale metadata must identify {expected_locale}")
    strings = data.get("strings")
    if not isinstance(strings, dict):
        return errors + ["locale strings must be an object"]
    if any(not isinstance(key, str) or not key or not isinstance(value, str) or not value
           for key, value in strings.items()):
        errors.append("locale strings must use non-empty string keys and values")
    if not all(any(key.startswith(prefix) for key in strings) for prefix in REQUIRED_TRANSLATION_PREFIXES):
        errors.append("locale is missing a protected translation namespace")
    return errors


def report(path: Path, errors: list[str]) -> bool:
    if errors:
        print(f"FAIL {path}: {'; '.join(errors)}", file=sys.stderr)
        return False
    print(f"PASS {path.name}: valid")
    return True


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    settings_path = root / "config/defaults/settings.json"
    en_path = root / "config/i18n/en.json"
    vi_path = root / "config/i18n/vi.json"
    try:
        checks = (
            report(settings_path, validate_settings(load_json(settings_path))),
            report(en_path, validate_locale(load_json(en_path), "en")),
            report(vi_path, validate_locale(load_json(vi_path), "vi")),
        )
    except ValueError as error:
        print(f"FAIL {error}", file=sys.stderr)
        return 1
    return 0 if all(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
