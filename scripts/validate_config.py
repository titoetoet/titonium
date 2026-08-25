#!/usr/bin/env python3
"""Dependency-free validation for Titonium's shipped JSON contracts."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


NODE_TYPES = {"widget", "group", "panel", "tabs", "spacer"}
BACKENDS = {"auto", "solid", "qml", "native"}


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"{path}: invalid JSON: {error}") from error


def validate_settings(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["settings must be an object"]
    if data.get("schemaVersion") != 2:
        errors.append("unsupported settings schemaVersion")
    if data.get("locale") not in {"vi", "en"}:
        errors.append("locale must be vi or en")
    appearance = data.get("appearance")
    if not isinstance(appearance, dict):
        errors.append("appearance is required")
    else:
        if not appearance.get("themeId"):
            errors.append("appearance.themeId is required")
        if appearance.get("mode") not in {"dark", "light"}:
            errors.append("appearance.mode is invalid")
        if appearance.get("density") not in {"compact", "comfortable"}:
            errors.append("appearance.density is invalid")
        if not isinstance(appearance.get("overrides"), dict):
            errors.append("appearance.overrides must be an object")
    accessibility = data.get("accessibility")
    if not isinstance(accessibility, dict) or not isinstance(accessibility.get("reducedMotion"), bool):
        errors.append("accessibility.reducedMotion is required")
    if not isinstance(data.get("modules"), dict):
        errors.append("modules must be an object")
    else:
        frame = data["modules"].get("frame")
        if frame is not None:
            if not isinstance(frame, dict):
                errors.append("modules.frame must be an object")
            else:
                if not isinstance(frame.get("enabled"), bool):
                    errors.append("modules.frame.enabled must be a boolean")
                thickness = frame.get("thickness")
                if not isinstance(thickness, int) or isinstance(thickness, bool) or not 1 <= thickness <= 8:
                    errors.append("modules.frame.thickness must be an integer from 1 to 8")
                radius = frame.get("cornerRadius")
                if not isinstance(radius, int) or isinstance(radius, bool) or not 0 <= radius <= 32:
                    errors.append("modules.frame.cornerRadius must be an integer from 0 to 32")
                opacity = frame.get("opacity")
                if not isinstance(opacity, (int, float)) or isinstance(opacity, bool) or not 0.3 <= opacity <= 1.0:
                    errors.append("modules.frame.opacity must be a number from 0.3 to 1.0")
        audio = data["modules"].get("audio")
        if audio is not None:
            if not isinstance(audio, dict):
                errors.append("modules.audio must be an object")
            else:
                for key, minimum, maximum in (("volumeStep", 1, 20), ("maxVolume", 50, 150), ("visualizerBars", 16, 64)):
                    value = audio.get(key)
                    if not isinstance(value, int) or isinstance(value, bool) or not minimum <= value <= maximum:
                        errors.append(f"modules.audio.{key} must be an integer from {minimum} to {maximum}")
                if not isinstance(audio.get("visualizerEnabled"), bool):
                    errors.append("modules.audio.visualizerEnabled must be a boolean")
                if audio.get("visualizerStyle") not in {"bars", "wave", "dots"}:
                    errors.append("modules.audio.visualizerStyle is invalid")
        launcher = data["modules"].get("launcher")
        if launcher is not None:
            if not isinstance(launcher, dict):
                errors.append("modules.launcher must be an object")
            else:
                if launcher.get("defaultCategory") not in {"all", "internet", "development", "media", "system"}:
                    errors.append("modules.launcher.defaultCategory is invalid")
                for key, minimum, maximum in (("resultLimit", 6, 48), ("columns", 4, 8)):
                    value = launcher.get(key)
                    if not isinstance(value, int) or isinstance(value, bool) or not minimum <= value <= maximum:
                        errors.append(f"modules.launcher.{key} must be an integer from {minimum} to {maximum}")
                for key in ("showSubtitles", "searchAutoFocus"):
                    if not isinstance(launcher.get(key), bool):
                        errors.append(f"modules.launcher.{key} must be a boolean")
        clock = data["modules"].get("clock")
        if clock is not None:
            if not isinstance(clock, dict):
                errors.append("modules.clock must be an object")
            else:
                for key in ("use24Hour", "showLunar"):
                    if not isinstance(clock.get(key), bool):
                        errors.append(f"modules.clock.{key} must be a boolean")
    return errors


def migrate_settings(data: Any) -> Any:
    if not isinstance(data, dict) or data.get("schemaVersion") != 1:
        return data
    legacy_theme = data.get("theme") if isinstance(data.get("theme"), dict) else {}
    accessibility = data.get("accessibility") if isinstance(data.get("accessibility"), dict) else {}
    modules = data.get("modules") if isinstance(data.get("modules"), dict) else {}
    return {
        "$schema": "titonium.settings/v2",
        "schemaVersion": 2,
        "locale": "en" if data.get("locale") == "en" else "vi",
        "appearance": {
            "themeId": "titonium-neutral",
            "mode": "light" if legacy_theme.get("mode") == "light" else "dark",
            "density": "comfortable",
            "overrides": {},
        },
        "accessibility": {"reducedMotion": accessibility.get("reducedMotion") is True},
        "modules": modules,
    }


def restore_appearance(settings: Any, defaults: Any) -> Any:
    restored = json.loads(json.dumps(settings))
    restored["appearance"] = json.loads(json.dumps(defaults["appearance"]))
    return restored


def validate_node(node: Any, path: str, seen: set[str], errors: list[str]) -> None:
    if not isinstance(node, dict):
        errors.append(f"{path} must be an object")
        return
    node_id = node.get("id")
    if not isinstance(node_id, str) or not node_id:
        errors.append(f"{path}.id is required")
    elif node_id in seen:
        errors.append(f"duplicate node id: {node_id}")
    else:
        seen.add(node_id)
    node_type = node.get("type")
    if node_type not in NODE_TYPES:
        errors.append(f"{path}.type is invalid")
        return
    if node_type == "widget" and not isinstance(node.get("widgetType"), str):
        errors.append(f"{path}.widgetType is required")
    if node_type == "group":
        children = node.get("children")
        if not isinstance(children, list):
            errors.append(f"{path}.children must be an array")
        else:
            for index, child in enumerate(children):
                validate_node(child, f"{path}.children[{index}]", seen, errors)
    if node_type == "panel":
        if "child" not in node:
            errors.append(f"{path}.child is required")
        else:
            validate_node(node["child"], f"{path}.child", seen, errors)
    if node_type == "tabs":
        pages = node.get("pages")
        if not isinstance(pages, list) or not pages:
            errors.append(f"{path}.pages must be a non-empty array")
        else:
            for index, page in enumerate(pages):
                if not isinstance(page, dict) or "child" not in page:
                    errors.append(f"{path}.pages[{index}].child is required")
                else:
                    validate_node(page["child"], f"{path}.pages[{index}].child", seen, errors)


def validate_layout(data: Any) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    if not isinstance(data, dict):
        return ["layout must be an object"]
    if data.get("schemaVersion") != 1:
        errors.append("unsupported layout schemaVersion")
    menubar = data.get("menubar")
    if not isinstance(menubar, dict):
        return errors + ["menubar is required"]
    height = menubar.get("height")
    if not isinstance(height, int) or isinstance(height, bool) or not 28 <= height <= 72:
        errors.append("menubar.height must be an integer from 28 to 72")
    for key in ("padding", "spacing"):
        value = menubar.get(key)
        if value is not None and (not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= 24):
            errors.append(f"menubar.{key} must be an integer from 0 to 24")
    screens = menubar.get("screens")
    if not isinstance(screens, dict) or "default" not in screens:
        return errors + ["menubar.screens.default is required"]
    for screen_name, screen in screens.items():
        slots = screen.get("slots") if isinstance(screen, dict) else None
        if not isinstance(slots, dict):
            errors.append(f"screen {screen_name} requires slots")
            continue
        for slot_name in ("start", "center", "end"):
            if slot_name not in slots:
                continue
            nodes = slots[slot_name]
            if not isinstance(nodes, list):
                errors.append(f"screen {screen_name} slot {slot_name} must be an array")
                continue
            for index, node in enumerate(nodes):
                validate_node(node, f"{screen_name}.{slot_name}[{index}]", seen, errors)
    return errors


def validate_theme(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["theme must be an object"]
    if data.get("schemaVersion") != 2:
        errors.append("unsupported theme schemaVersion")
    if not data.get("id"):
        errors.append("theme.id is required")
    if not data.get("version"):
        errors.append("theme.version is required")
    if not data.get("nameKey"):
        errors.append("theme.nameKey is required")
    if not isinstance(data.get("immutable"), bool):
        errors.append("theme.immutable is required")
    modes = data.get("modes")
    if not isinstance(modes, dict) or not isinstance(modes.get("dark"), dict) or not isinstance(modes.get("light"), dict):
        errors.append("theme dark/light modes are required")
    for key in ("typography", "metrics", "motion", "material"):
        if not isinstance(data.get(key), dict):
            errors.append(f"theme.{key} is required")
    typography = data.get("typography")
    if isinstance(typography, dict):
        for key in ("fontFamily", "fallbackFamily", "monoFamily", "iconFamily"):
            if not isinstance(typography.get(key), str) or not typography[key]:
                errors.append(f"theme.typography.{key} is required")
        for key in (
            "microSize", "captionSize", "bodySmallSize", "bodySize", "bodyLargeSize",
            "labelSize", "titleSmallSize", "titleSize", "titleLargeSize", "displaySize",
        ):
            value = typography.get(key)
            if not isinstance(value, int) or isinstance(value, bool) or not 8 <= value <= 64:
                errors.append(f"theme.typography.{key} must be an integer from 8 to 64")
        weights = typography.get("weights")
        if not isinstance(weights, dict):
            errors.append("theme.typography.weights is required")
        else:
            for key in ("regular", "medium", "semibold", "bold"):
                value = weights.get(key)
                if not isinstance(value, int) or isinstance(value, bool) or not 100 <= value <= 900:
                    errors.append(f"theme.typography.weights.{key} must be an integer from 100 to 900")
    material = data.get("material")
    if isinstance(material, dict):
        if material.get("defaultBackend") not in BACKENDS:
            errors.append("theme.material.defaultBackend is invalid")
        if not isinstance(material.get("allowedBackends"), list) or not material.get("allowedBackends"):
            errors.append("theme.material.allowedBackends is required")
        elif any(backend not in {"solid", "qml", "native"} for backend in material["allowedBackends"]):
            errors.append("theme.material.allowedBackends contains an invalid backend")
        elif material.get("defaultBackend") != "auto" and material.get("defaultBackend") not in material["allowedBackends"]:
            errors.append("theme.material.defaultBackend must be allowed")
        if not isinstance(material.get("compositorIntegration"), bool):
            errors.append("theme.material.compositorIntegration is required")
        for key in ("opacity", "tintOpacity", "borderOpacity", "specularOpacity"):
            value = material.get(key)
            if value is not None and (not isinstance(value, (int, float)) or isinstance(value, bool) or not 0 <= value <= 1):
                errors.append(f"theme.material.{key} must be a number from 0 to 1")
    return errors


def validate_theme_catalog(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["theme catalog must be an object"]
    if data.get("schemaVersion") != 1:
        errors.append("unsupported theme catalog schemaVersion")
    default_id = data.get("defaultThemeId")
    entries = data.get("themes")
    if not default_id:
        errors.append("theme catalog defaultThemeId is required")
    if not isinstance(entries, list) or not entries:
        return errors + ["theme catalog themes are required"]
    ids: set[str] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict) or not entry.get("id") or not entry.get("file"):
            errors.append(f"theme catalog entry {index} is invalid")
        elif "/" in entry["file"] or ".." in entry["file"] or not entry["file"].endswith(".json"):
            errors.append(f"theme catalog entry {entry['id']} has an invalid file name")
        elif entry["id"] in ids:
            errors.append(f"duplicate theme catalog id: {entry['id']}")
        else:
            ids.add(entry["id"])
    if default_id not in ids:
        errors.append("theme catalog default is not registered")
    return errors


def expect_migration(path: Path) -> bool:
    source = load_json(path)
    migrated = migrate_settings(source)
    errors = validate_settings(migrated)
    defaults = load_json(path.parents[2] / "config/defaults/settings.json")
    restored = restore_appearance(migrated, defaults)
    preserved = (
        migrated.get("locale") == "en"
        and migrated.get("appearance", {}).get("themeId") == "titonium-neutral"
        and migrated.get("appearance", {}).get("mode") == "light"
        and migrated.get("accessibility", {}).get("reducedMotion") is True
        and migrated.get("modules", {}).get("sentinel", {}).get("enabled") is True
        and restored.get("appearance") == defaults.get("appearance")
        and restored.get("locale") == "en"
        and restored.get("accessibility", {}).get("reducedMotion") is True
        and restored.get("modules", {}).get("sentinel", {}).get("enabled") is True
    )
    if errors or not preserved:
        print(f"FAIL {path}: migration errors={errors}; preserved={preserved}", file=sys.stderr)
        return False
    print(f"PASS {path.name}: migrated v1 -> v2 with non-appearance state preserved")
    return True


def expect(path: Path, validator: Any, should_pass: bool) -> bool:
    try:
        errors = validator(load_json(path))
    except ValueError as error:
        errors = [str(error)]
    passed = not errors
    if passed != should_pass:
        expectation = "valid" if should_pass else "invalid"
        print(f"FAIL {path}: expected {expectation}; errors={errors}", file=sys.stderr)
        return False
    print(f"PASS {path.name}: {'valid' if passed else 'rejected'}")
    return True


def expect_theme_contracts(root: Path) -> bool:
    neutral = load_json(root / "config/themes/titonium-neutral.json")
    hybrid = load_json(root / "config/themes/titonium-hybrid-glass.json")
    valid = (
        neutral.get("immutable") is True
        and neutral.get("material") == {
            "defaultBackend": "solid",
            "allowedBackends": ["solid"],
            "compositorIntegration": False,
            "opacity": 1.0,
        }
        and hybrid.get("material", {}).get("defaultBackend") == "auto"
        and {"native", "qml", "solid"}.issubset(set(hybrid.get("material", {}).get("allowedBackends", [])))
    )
    if not valid:
        print("FAIL immutable Neutral or hybrid fallback material contract", file=sys.stderr)
        return False
    print("PASS Neutral solid restore and hybrid fallback material contracts")
    return True


def expect_derived_rejections(root: Path) -> bool:
    settings = load_json(root / "config/defaults/settings.json")
    settings["modules"]["audio"]["volumeStep"] = 0
    settings["modules"]["launcher"]["columns"] = "six"
    settings["modules"]["clock"]["showLunar"] = "yes"
    theme = load_json(root / "config/themes/titonium-hybrid-glass.json")
    theme["material"]["defaultBackend"] = "native"
    theme["material"]["allowedBackends"] = ["solid"]
    theme["material"]["tintOpacity"] = 2
    rejected = bool(validate_settings(settings)) and bool(validate_theme(theme))
    if not rejected:
        print("FAIL invalid module/material derivatives were accepted", file=sys.stderr)
        return False
    print("PASS invalid Audio/Launcher/Clock and material derivatives rejected")
    return True


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    cases = (
        (root / "config/defaults/settings.json", validate_settings, True),
        (root / "config/defaults/layout.json", validate_layout, True),
        (root / "config/themes/index.json", validate_theme_catalog, True),
        (root / "config/themes/titonium-neutral.json", validate_theme, True),
        (root / "config/themes/titonium-hybrid-glass.json", validate_theme, True),
        (root / "tests/fixtures/layout.valid.json", validate_layout, True),
        (root / "tests/fixtures/layout.invalid-duplicate.json", validate_layout, False),
        (root / "tests/fixtures/layout.invalid-type.json", validate_layout, False),
        (root / "tests/fixtures/layout.invalid-metrics.json", validate_layout, False),
        (root / "tests/fixtures/settings.invalid.json", validate_settings, False),
        (root / "tests/fixtures/settings.invalid-frame.json", validate_settings, False),
        (root / "tests/fixtures/theme.invalid-typography.json", validate_theme, False),
    )
    passed = (
        all(expect(*case) for case in cases)
        and expect_migration(root / "tests/fixtures/settings.v1.valid.json")
        and expect_theme_contracts(root)
        and expect_derived_rejections(root)
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
