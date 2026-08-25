#!/usr/bin/env python3
"""Dependency-free validation for Titonium's shipped JSON contracts."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


NODE_TYPES = {"widget", "group", "panel", "tabs", "spacer"}
BACKENDS = {"auto", "native", "qml", "solid"}


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"{path}: invalid JSON: {error}") from error


def validate_settings(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["settings must be an object"]
    if data.get("schemaVersion") != 1:
        errors.append("unsupported settings schemaVersion")
    if data.get("locale") not in {"vi", "en"}:
        errors.append("locale must be vi or en")
    theme = data.get("theme")
    if not isinstance(theme, dict):
        errors.append("theme is required")
    else:
        if not theme.get("id"):
            errors.append("theme.id is required")
        if theme.get("mode") not in {"dark", "light"}:
            errors.append("theme.mode is invalid")
        if theme.get("materialBackend") not in BACKENDS:
            errors.append("theme.materialBackend is invalid")
    accessibility = data.get("accessibility")
    if not isinstance(accessibility, dict) or not isinstance(accessibility.get("reducedMotion"), bool):
        errors.append("accessibility.reducedMotion is required")
    return errors


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
    if data.get("schemaVersion") != 1:
        errors.append("unsupported theme schemaVersion")
    if not data.get("id"):
        errors.append("theme.id is required")
    modes = data.get("modes")
    if not isinstance(modes, dict) or not isinstance(modes.get("dark"), dict) or not isinstance(modes.get("light"), dict):
        errors.append("theme dark/light modes are required")
    for key in ("typography", "metrics", "motion", "materials"):
        if not isinstance(data.get(key), dict):
            errors.append(f"theme.{key} is required")
    return errors


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


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    cases = (
        (root / "config/defaults/settings.json", validate_settings, True),
        (root / "config/defaults/layout.json", validate_layout, True),
        (root / "config/themes/titonium-foundation.json", validate_theme, True),
        (root / "tests/fixtures/layout.valid.json", validate_layout, True),
        (root / "tests/fixtures/layout.invalid-duplicate.json", validate_layout, False),
        (root / "tests/fixtures/layout.invalid-type.json", validate_layout, False),
        (root / "tests/fixtures/settings.invalid.json", validate_settings, False),
    )
    return 0 if all(expect(*case) for case in cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
