#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULTS = ROOT / "config/defaults/dock.json"
SCHEMA = ROOT / "config/schemas/dock.schema.json"
STORE = ROOT / "Titonium/Services/Dock/DockStore.qml"
SERVICE_ROOT = ROOT / "Titonium/Services/Dock"

EXPECTED_DEFAULTS = {
    "$schema": "titonium.dock/v1",
    "schemaVersion": 1,
    "pinnedIds": [],
    "pinnedOpen": False,
    "autoHide": True,
}
STORE_FRAGMENTS = (
    "import qs.Titonium.Core.Runtime",
    "readonly property string visibilityMode: Preferences.dock.visibilityMode",
    "readonly property var pinnedIds:",
    "readonly property bool pinnedOpen:",
    "readonly property bool autoHide:",
    "function setVisibilityMode(mode: string): bool",
    "function setPinnedIds(ids: var): bool",
    "function togglePin(appId: string): var",
    "function isPinned(appId: string): bool",
    "function movePin(fromIndex: int, toIndex: int): bool",
    "function setPinnedOpen(value: bool): var",
    "function snapshot(): var",
    "Preferences.previewActive",
    "Preferences.patch(\"modules.dock.",
    "Preferences.commitPatch(\"modules.dock.",
    "DockRules.movePinnedId",
    "DockRules.visibilityPolicy",
)
FORBIDDEN_STORE_FRAGMENTS = (
    "Process", "FileView", "Quickshell.Io", "dock.json", "atomicWrites",
    "property var state:", "setText", "execDetached", "hyprctl",
)


def read_json(path: Path, label: str, errors: list[str]) -> object | None:
    if not path.is_file():
        errors.append(f"missing {label}: {path.relative_to(ROOT)}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as failure:
        errors.append(f"invalid {label} JSON: {failure}")
        return None


def validate_document(errors: list[str]) -> None:
    defaults = read_json(DEFAULTS, "Dock defaults", errors)
    schema = read_json(SCHEMA, "Dock schema", errors)
    if defaults is not None and defaults != EXPECTED_DEFAULTS:
        errors.append("Dock defaults must be exactly titonium.dock/v1 []/false/true")
    if not isinstance(schema, dict):
        return
    if schema.get("$id") != "titonium.dock/v1":
        errors.append("Dock schema must identify titonium.dock/v1")
    if schema.get("type") != "object" or schema.get("additionalProperties") is not False:
        errors.append("Dock schema must be a closed object")
    properties = schema.get("properties")
    if not isinstance(properties, dict):
        errors.append("Dock schema has no properties object")
        return
    expected_types = {
        "$schema": "string",
        "schemaVersion": "integer",
        "pinnedIds": "array",
        "pinnedOpen": "boolean",
        "autoHide": "boolean",
    }
    if schema.get("required") != list(expected_types):
        errors.append("Dock schema must require its five v1 fields in order")
    for key, type_name in expected_types.items():
        if properties.get(key, {}).get("type") != type_name:
            errors.append(f"Dock schema {key} must be a {type_name}")
    if properties.get("$schema", {}).get("const") != "titonium.dock/v1":
        errors.append("Dock schema $schema must be titonium.dock/v1")
    if properties.get("schemaVersion", {}).get("const") != 1:
        errors.append("Dock schema schemaVersion must be 1")
    item_schema = properties.get("pinnedIds", {}).get("items", {})
    if item_schema.get("type") != "string" or item_schema.get("minLength") != 1:
        errors.append("Dock schema pins must be non-empty strings")


def validate_store(errors: list[str]) -> None:
    if not STORE.is_file():
        errors.append("missing DockStore.qml")
        return
    source = STORE.read_text(encoding="utf-8")
    for fragment in STORE_FRAGMENTS:
        if fragment not in source:
            errors.append(f"Dock store missing contract: {fragment}")
    for fragment in FORBIDDEN_STORE_FRAGMENTS:
        if fragment in source:
            errors.append(f"Dock store has forbidden runtime dependency: {fragment}")
    if "FileView {" in source:
        errors.append("DockStore must not own persistence after settings v7 migration")
    for path in ROOT.rglob("*.qml"):
        if path == STORE:
            continue
        if "FileView" in path.read_text(encoding="utf-8") and SERVICE_ROOT in path.parents:
            errors.append(f"Dock FileView ownership escapes DockStore: {path.relative_to(ROOT)}")


def main() -> int:
    errors: list[str] = []
    validate_document(errors)
    validate_store(errors)
    if errors:
        for error in errors:
            print(f"FAIL {error}")
        return 1
    print("PASS Dock schema and runtime store fixtures")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
