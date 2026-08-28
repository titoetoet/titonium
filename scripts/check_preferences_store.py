#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREFERENCES = ROOT / "Titonium/Core/Runtime/Preferences.qml"


def main() -> int:
    errors: list[str] = []
    source = PREFERENCES.read_text(encoding="utf-8") if PREFERENCES.is_file() else ""

    required = (
        "property var committedState:",
        "property var previewState:",
        "property var pendingApplyState:",
        "property bool previewActive: false",
        "property bool savePending: false",
        "property int pendingRuntimeWrites: 0",
        "property string lastError:",
        "readonly property var effectiveState:",
        "readonly property var settings: root.effectiveState",
        "readonly property bool dirty:",
        "readonly property var bar:",
        "readonly property var dock:",
        "readonly property var notifications:",
        "function beginPreview(): bool",
        "function patch(path: string, value: var): bool",
        "function apply(): bool",
        "function cancel(): void",
        "function restoreAppearance(): bool",
        "function commitPatch(path: string, value: var): bool",
        "Validator.project(runtime, defaults, legacyDock)",
        'Quickshell.dataPath("settings.json")',
        'Quickshell.dataPath("dock.json")',
        "atomicWrites: true",
        "watchChanges: !root.previewActive && root.pendingRuntimeWrites === 0",
        "onFileChanged: root.reload()",
        "onSaved:",
        "onSaveFailed:",
    )
    for fragment in required:
        if fragment not in source:
            errors.append(f"Preferences store missing contract: {fragment}")

    for forbidden in (
        "runtime || defaults",
        "Component.onCompleted: runtimeFile.setText",
        "Component.onCompleted: root.apply",
    ):
        if forbidden in source:
            errors.append(f"Preferences store retains unsafe ownership: {forbidden}")
    if re.search(r"^\s*property\s+var\s+settings\s*:", source, re.MULTILINE):
        errors.append("Preferences store exposes mutable settings state")

    settings_writers: list[str] = []
    for path in (ROOT / "Titonium").rglob("*.qml"):
        candidate = path.read_text(encoding="utf-8")
        if 'Quickshell.dataPath("settings.json")' in candidate and "setText(" in candidate:
            settings_writers.append(str(path.relative_to(ROOT)))
        if "/Settings/" in str(path) and ("FileView" in candidate or "Process" in candidate):
            errors.append(f"Settings view owns persistence/process: {path.relative_to(ROOT)}")
        if path != PREFERENCES and re.search(r"\bPreferences\.settings\s*=", candidate):
            errors.append(f"external source assigns Preferences.settings: {path.relative_to(ROOT)}")
    if settings_writers != ["Titonium/Core/Runtime/Preferences.qml"]:
        errors.append(f"settings.json writer ownership is not singular: {settings_writers}")

    if errors:
        for error in errors:
            print("FAIL " + error)
        return 1
    print("PASS transactional Preferences ownership and atomic-write contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
