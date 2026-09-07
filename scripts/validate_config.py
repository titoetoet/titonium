#!/usr/bin/env python3
"""Validate the small shipped contract consumed by the protected skeleton."""

from __future__ import annotations

import json
import math
import re
import sys
from pathlib import Path
from typing import Any


REQUIRED_SETTINGS_KEYS = {
    "$schema", "schemaVersion", "locale", "appearance", "accessibility", "applications", "modules"
}
REQUIRED_TRANSLATION_PREFIXES = (
    "application.error.", "clipboard.error.", "menubar.input_method.",
    "menubar.workspace.", "spotlight.",
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
    if data.get("$schema") != "titonium.settings/v8" or data.get("schemaVersion") != 8:
        errors.append("settings schema must be titonium.settings/v8")
    if data.get("locale") not in {"vi", "en"}:
        errors.append("locale must be vi or en")

    appearance = data.get("appearance")
    themes = {"glassmorphism", "material", "liquid-glass", "modern-flat", "neumorphism",
              "neutral", "glass", "soft", "graphite"}
    if not isinstance(appearance, dict) or set(appearance) != {"mode", "themeId", "themeOverrides", "wallpaper"}:
        errors.append("appearance has an invalid shape")
    else:
        if appearance.get("mode") not in {"dark", "light", "system"}:
            errors.append("appearance.mode is invalid")
        if appearance.get("themeId") not in themes:
            errors.append("appearance.themeId is invalid")
        wallpaper = appearance.get("wallpaper")
        if (not isinstance(wallpaper, dict) or set(wallpaper) != {"policy", "customPath"}
                or wallpaper.get("policy") not in {"keep", "theme", "custom"}
                or not isinstance(wallpaper.get("customPath"), str)):
            errors.append("appearance.wallpaper is invalid")
        ranges = {"backgroundOpacity": (.85, 1), "borderStrength": (0, 1),
                  "shadowStrength": (0, 1), "sheenStrength": (0, 1),
                  "radiusScale": (.75, 1.25), "motionScale": (.5, 1.5)}
        overrides = appearance.get("themeOverrides")
        if not isinstance(overrides, dict) or not set(overrides).issubset(themes):
            errors.append("appearance.themeOverrides is invalid")
        else:
            for theme in overrides.values():
                if not isinstance(theme, dict) or not set(theme).issubset({"light", "dark"}):
                    errors.append("appearance override modes are invalid")
                    continue
                for fields in theme.values():
                    if not isinstance(fields, dict) or not set(fields).issubset(set(ranges) | {"accent"}):
                        errors.append("appearance override fields are invalid")
                        continue
                    for key, value in fields.items():
                        if key == "accent":
                            if not isinstance(value, str) or not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
                                errors.append("appearance accent is invalid")
                        elif (isinstance(value, bool) or not isinstance(value, (int, float))
                              or not math.isfinite(value) or not ranges[key][0] <= value <= ranges[key][1]):
                            errors.append("appearance override range is invalid")

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
    expected_modules = {"spotlight", "bar", "dock", "notifications", "clock", "audio"}
    if not isinstance(modules, dict) or set(modules) != expected_modules:
        errors.append("modules must contain the exact v8 module preferences")
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
    bar = modules.get("bar")
    required_bar = {"workspaceCount", "autoHide", "mascotEnabled", "style"}
    if (not isinstance(bar, dict) or not required_bar.issubset(bar)
            or not set(bar).issubset(required_bar | {"height", "mascot"})):
        errors.append("modules.bar has an invalid shape")
    else:
        height = bar.get("height", 44)
        if not isinstance(height, int) or isinstance(height, bool) or not 40 <= height <= 64:
            errors.append("modules.bar.height must be an integer from 40 to 64")
        if bar.get("mascot", "pig") not in {"pig", "pig-lavender", "dog"}:
            errors.append("modules.bar.mascot is invalid")
        count = bar.get("workspaceCount")
        if not isinstance(count, int) or isinstance(count, bool) or not 1 <= count <= 8:
            errors.append("modules.bar.workspaceCount must be an integer from 1 to 8")
        if not isinstance(bar.get("autoHide"), bool):
            errors.append("modules.bar.autoHide must be a boolean")
        if not isinstance(bar.get("mascotEnabled"), bool):
            errors.append("modules.bar.mascotEnabled must be a boolean")
        if bar.get("style") not in {"connected", "classic"}:
            errors.append("modules.bar.style is invalid")
    dock = modules.get("dock")
    if not isinstance(dock, dict) or set(dock) not in ({"visibilityMode", "pinnedIds"}, {"visibilityMode", "pinnedIds", "style"}):
        errors.append("modules.dock has an invalid shape")
    else:
        if dock.get("visibilityMode") not in {"auto-hide", "always-visible", "reserve-space", "hidden"}:
            errors.append("modules.dock.visibilityMode is invalid")
        if dock.get("style", "follow-topbar") not in {"follow-topbar", "connected", "classic"}:
            errors.append("modules.dock.style is invalid")
        pinned_ids = dock.get("pinnedIds")
        if not isinstance(pinned_ids, list):
            errors.append("modules.dock.pinnedIds must be an array")
        elif any(not isinstance(entry, str) or not entry for entry in pinned_ids):
            errors.append("modules.dock.pinnedIds must contain non-empty strings")
        elif len({entry.casefold() for entry in pinned_ids}) != len(pinned_ids):
            errors.append("modules.dock.pinnedIds must be case-insensitively unique")
    notifications = modules.get("notifications")
    if not isinstance(notifications, dict) or set(notifications) != {
            "toastsEnabled", "toastDuration", "policyMode", "allowCriticalOnIsland",
            "keepCriticalUnread", "applicationOverrides"}:
        errors.append("modules.notifications has an invalid shape")
    else:
        if not isinstance(notifications.get("toastsEnabled"), bool):
            errors.append("modules.notifications.toastsEnabled must be a boolean")
        toast_duration = notifications.get("toastDuration")
        if (not isinstance(toast_duration, int) or isinstance(toast_duration, bool)
                or not 2000 <= toast_duration <= 10000):
            errors.append("modules.notifications.toastDuration must be an integer from 2000 to 10000")
        if notifications.get("policyMode") not in {"automatic", "custom"}:
            errors.append("modules.notifications.policyMode is invalid")
        if not isinstance(notifications.get("allowCriticalOnIsland"), bool):
            errors.append("modules.notifications.allowCriticalOnIsland must be a boolean")
        if not isinstance(notifications.get("keepCriticalUnread"), bool):
            errors.append("modules.notifications.keepCriticalUnread must be a boolean")
        overrides = notifications.get("applicationOverrides")
        if not isinstance(overrides, dict):
            errors.append("modules.notifications.applicationOverrides must be an object")
        elif any(not isinstance(app_id, str) or not app_id.strip()
                 or app_id.strip() in {"__proto__", "prototype", "constructor"}
                 or mode not in {"follow", "quiet", "normal", "critical", "block"}
                 for app_id, mode in overrides.items()):
            errors.append("modules.notifications.applicationOverrides is invalid")
    clock = modules.get("clock")
    if not isinstance(clock, dict) or set(clock) != {"use24Hour"}:
        errors.append("modules.clock must contain only use24Hour")
    elif not isinstance(clock.get("use24Hour"), bool):
        errors.append("modules.clock.use24Hour must be a boolean")
    audio = modules.get("audio")
    if not isinstance(audio, dict) or set(audio) != {"allowAmplification"}:
        errors.append("modules.audio must contain only allowAmplification")
    elif not isinstance(audio.get("allowAmplification"), bool):
        errors.append("modules.audio.allowAmplification must be a boolean")
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
        en_data = load_json(en_path)
        vi_data = load_json(vi_path)
        locale_key_errors: list[str] = []
        en_strings = en_data.get("strings", {}) if isinstance(en_data, dict) else {}
        vi_strings = vi_data.get("strings", {}) if isinstance(vi_data, dict) else {}
        if isinstance(en_strings, dict) and isinstance(vi_strings, dict):
            missing_vi = sorted(set(en_strings) - set(vi_strings))
            missing_en = sorted(set(vi_strings) - set(en_strings))
            if missing_vi:
                locale_key_errors.append("vi is missing keys: " + ", ".join(missing_vi))
            if missing_en:
                locale_key_errors.append("en is missing keys: " + ", ".join(missing_en))
        checks = (
            report(settings_path, validate_settings(load_json(settings_path))),
            report(en_path, validate_locale(en_data, "en")),
            report(vi_path, validate_locale(vi_data, "vi")),
            report(Path("locale-key-parity"), locale_key_errors),
        )
    except ValueError as error:
        print(f"FAIL {error}", file=sys.stderr)
        return 1
    return 0 if all(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
