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
    if data.get("schemaVersion") != 5:
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
    applications = data.get("applications")
    if not isinstance(applications, dict):
        errors.append("applications must be an object")
    else:
        hidden_ids = applications.get("hiddenIds")
        if not isinstance(hidden_ids, list):
            errors.append("applications.hiddenIds must be an array")
        else:
            if any(not isinstance(entry_id, str) or not entry_id for entry_id in hidden_ids):
                errors.append("applications.hiddenIds entries must be non-empty strings")
            elif len(set(hidden_ids)) != len(hidden_ids):
                errors.append("applications.hiddenIds must contain unique IDs")
        for key in applications.keys() - {"hiddenIds"}:
            errors.append(f"applications.{key} is invalid")
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
        spotlight = data["modules"].get("spotlight")
        if spotlight is not None:
            if not isinstance(spotlight, dict):
                errors.append("modules.spotlight must be an object")
            else:
                if spotlight.get("pageTransition") not in {"none", "slide", "slide-fade", "slide-scale"}:
                    errors.append("modules.spotlight.pageTransition is invalid")
                duration = spotlight.get("transitionDuration")
                if not isinstance(duration, int) or isinstance(duration, bool) or not 80 <= duration <= 500:
                    errors.append("modules.spotlight.transitionDuration must be an integer from 80 to 500")
                allowed = {"pageTransition", "transitionDuration"}
                for key in spotlight.keys() - allowed:
                    errors.append(f"modules.spotlight.{key} is invalid")
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
    if not isinstance(data, dict) or data.get("schemaVersion") not in {1, 2, 3, 4, 5}:
        return data
    current = json.loads(json.dumps(data))
    if current.get("schemaVersion") == 1:
        legacy_theme = current.get("theme") if isinstance(current.get("theme"), dict) else {}
        accessibility = current.get("accessibility") if isinstance(current.get("accessibility"), dict) else {}
        modules = current.get("modules") if isinstance(current.get("modules"), dict) else {}
        current = {
            "$schema": "titonium.settings/v2",
            "schemaVersion": 2,
            "locale": "en" if current.get("locale") == "en" else "vi",
            "appearance": {
                "themeId": "titonium-neutral",
                "mode": "light" if legacy_theme.get("mode") == "light" else "dark",
                "density": "comfortable",
                "overrides": {},
            },
            "accessibility": {"reducedMotion": accessibility.get("reducedMotion") is True},
            "modules": modules,
        }
    if current.get("schemaVersion") == 2:
        modules = current.get("modules") if isinstance(current.get("modules"), dict) else {}
        launcher = modules.get("launcher")
        if isinstance(launcher, dict):
            modules["launcher"] = {
                "username": launcher.get("username") if isinstance(launcher.get("username"), str) else "",
                "avatarIcon": launcher.get("avatarIcon") or "terminal",
                "pageTransition": launcher.get("pageTransition") or "slide-fade",
                "transitionDuration": launcher.get("transitionDuration")
                if isinstance(launcher.get("transitionDuration"), int) else 220,
            }
        current["$schema"] = "titonium.settings/v3"
        current["schemaVersion"] = 3
    if current.get("schemaVersion") == 3:
        modules = current.get("modules") if isinstance(current.get("modules"), dict) else {}
        launcher = modules.get("launcher") if isinstance(modules.get("launcher"), dict) else {}
        modules["spotlight"] = {
            "pageTransition": launcher.get("pageTransition") or "slide-fade",
            "transitionDuration": launcher.get("transitionDuration")
            if isinstance(launcher.get("transitionDuration"), int) and not isinstance(launcher.get("transitionDuration"), bool) else 220,
        }
        modules.pop("launcher", None)
        current["modules"] = modules
        current["$schema"] = "titonium.settings/v4"
        current["schemaVersion"] = 4
    if current.get("schemaVersion") == 4:
        current["applications"] = {"hiddenIds": []}
        current["$schema"] = "titonium.settings/v5"
        current["schemaVersion"] = 5
    return current


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
        migrated.get("schemaVersion") == 5
        and migrated.get("$schema") == "titonium.settings/v5"
        and migrated.get("applications") == {"hiddenIds": []}
        and migrated.get("locale") == "en"
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
    print(f"PASS {path.name}: migrated v1 -> v5 with non-appearance state preserved")
    return True


def expect_spotlight_v2_migration(path: Path) -> bool:
    migrated = migrate_settings(load_json(path))
    spotlight = migrated.get("modules", {}).get("spotlight", {})
    retired = {"defaultCategory", "resultLimit", "columns", "showSubtitles", "searchAutoFocus"}
    valid = (
        migrated.get("schemaVersion") == 5
        and migrated.get("$schema") == "titonium.settings/v5"
        and migrated.get("applications") == {"hiddenIds": []}
        and spotlight == {
            "pageTransition": "slide-scale",
            "transitionDuration": 280,
        }
        and retired.isdisjoint(spotlight)
        and "launcher" not in migrated.get("modules", {})
        and migrated.get("modules", {}).get("sentinel", {}).get("enabled") is True
    )
    if not valid:
        print(f"FAIL {path}: v2 spotlight migration produced {spotlight}", file=sys.stderr)
        return False
    print(f"PASS {path.name}: migrated v2 -> v5 and removed retired Launcher fields")
    return True


def expect_spotlight_v3_migration(path: Path) -> bool:
    source = load_json(path)
    migrated = migrate_settings(source)
    preserved = (
        migrated.get("$schema") == "titonium.settings/v5"
        and migrated.get("schemaVersion") == 5
        and migrated.get("applications") == {"hiddenIds": []}
        and migrated.get("locale") == "en"
        and migrated.get("appearance") == {
            "themeId": "titonium-hybrid-glass",
            "mode": "light",
            "density": "compact",
            "overrides": {"metrics": {"spacingMedium": 14}},
        }
        and migrated.get("accessibility") == {"reducedMotion": True}
        and migrated.get("modules", {}).get("frame") == {
            "enabled": True,
            "thickness": 4,
            "cornerRadius": 18,
            "opacity": 0.7,
        }
        and migrated.get("modules", {}).get("audio") == {
            "volumeStep": 9,
            "maxVolume": 125,
            "visualizerEnabled": True,
            "visualizerStyle": "wave",
            "visualizerBars": 48,
        }
        and migrated.get("modules", {}).get("clock") == {
            "use24Hour": False,
            "showLunar": False,
        }
        and migrated.get("modules", {}).get("sentinel") == {"enabled": True}
        and "launcher" not in migrated.get("modules", {})
        and migrated.get("modules", {}).get("spotlight") == {
            "pageTransition": "slide-scale",
            "transitionDuration": 280,
        }
    )
    if not preserved:
        print(f"FAIL {path}: v3 spotlight migration produced {migrated}", file=sys.stderr)
        return False
    print(f"PASS {path.name}: migrated v3 -> v5 with Spotlight preferences and unrelated state preserved")
    return True


def expect_v4_visibility_migration(path: Path) -> bool:
    source = load_json(path)
    migrated = migrate_settings(source)
    valid = (
        migrated.get("$schema") == "titonium.settings/v5"
        and migrated.get("schemaVersion") == 5
        and migrated.get("applications") == {"hiddenIds": []}
        and migrated.get("locale") == source.get("locale")
        and migrated.get("appearance") == source.get("appearance")
        and migrated.get("accessibility") == source.get("accessibility")
        and migrated.get("modules") == source.get("modules")
    )
    if not valid:
        print(f"FAIL {path}: v4 visibility migration produced {migrated}", file=sys.stderr)
        return False
    print(f"PASS {path.name}: migrated v4 -> v5 with global visibility defaults")
    return True


def expect_application_visibility_rejections(root: Path) -> bool:
    expected = {
        "duplicate": "applications.hiddenIds must contain unique IDs",
        "empty": "applications.hiddenIds entries must be non-empty strings",
        "non-string": "applications.hiddenIds entries must be non-empty strings",
        "unknown": "applications.unknown is invalid",
    }
    observed: dict[str, list[str]] = {}
    for case in expected:
        settings = load_json(root / "config/defaults/settings.json")
        if case == "duplicate":
            settings["applications"] = {"hiddenIds": ["a.desktop", "a.desktop"]}
        elif case == "empty":
            settings["applications"] = {"hiddenIds": [""]}
        elif case == "non-string":
            settings["applications"] = {"hiddenIds": [3]}
        else:
            settings["applications"] = {"hiddenIds": [], "unknown": True}
        observed[case] = validate_settings(settings)
    valid = all(observed[case] == [message] for case, message in expected.items())
    if not valid:
        print(f"FAIL isolated application visibility derivatives: {observed}", file=sys.stderr)
        return False
    print("PASS invalid application visibility derivatives rejected independently")
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


def expect_spotlight_unknown_rejection(root: Path) -> bool:
    settings = load_json(root / "config/defaults/settings.json")
    settings["modules"]["spotlight"]["unknown"] = True
    errors = validate_settings(settings)
    valid = errors == ["modules.spotlight.unknown is invalid"]
    if not valid:
        print(f"FAIL unknown Spotlight key rejection was not isolated: {errors}", file=sys.stderr)
        return False
    print("PASS unknown Spotlight key rejected independently")
    return True


def expect_other_derived_rejections(root: Path) -> bool:
    audio = load_json(root / "config/defaults/settings.json")
    audio["modules"]["audio"]["volumeStep"] = 0
    clock = load_json(root / "config/defaults/settings.json")
    clock["modules"]["clock"]["showLunar"] = "yes"
    audio_errors = validate_settings(audio)
    clock_errors = validate_settings(clock)
    valid = (
        audio_errors == ["modules.audio.volumeStep must be an integer from 1 to 20"]
        and clock_errors == ["modules.clock.showLunar must be a boolean"]
    )
    if not valid:
        print(
            f"FAIL isolated Audio/Clock derivatives: audio={audio_errors}; clock={clock_errors}",
            file=sys.stderr,
        )
        return False
    print("PASS invalid Audio and Clock derivatives rejected independently")
    return True


def expect_theme_derivative_rejections(root: Path) -> bool:
    theme = load_json(root / "config/themes/titonium-hybrid-glass.json")
    theme["material"]["defaultBackend"] = "native"
    theme["material"]["allowedBackends"] = ["solid"]
    theme["material"]["tintOpacity"] = 2
    errors = validate_theme(theme)
    rejected = bool(errors)
    if not rejected:
        print("FAIL invalid material derivative was accepted", file=sys.stderr)
        return False
    print("PASS invalid material derivative rejected")
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
        (root / "tests/fixtures/settings.invalid-applications.json", validate_settings, False),
        (root / "tests/fixtures/theme.invalid-typography.json", validate_theme, False),
    )
    checks = [
        all(expect(*case) for case in cases),
        expect_migration(root / "tests/fixtures/settings.v1.valid.json"),
        expect_spotlight_v2_migration(root / "tests/fixtures/settings.v2.launcher.json"),
        expect_spotlight_v3_migration(root / "tests/fixtures/settings.v3.spotlight.json"),
        expect_v4_visibility_migration(root / "tests/fixtures/settings.v4.valid.json"),
        expect_theme_contracts(root),
        expect_spotlight_unknown_rejection(root),
        expect_other_derived_rejections(root),
        expect_application_visibility_rejections(root),
        expect_theme_derivative_rejections(root),
    ]
    passed = all(checks)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
