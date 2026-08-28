#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CENTER = ROOT / "Titonium/Services/Center"
SERVICE = CENTER / "CenterActivityService.qml"
RULES = CENTER / "CenterActivityRules.js"
QMLDIR = CENTER / "qmldir"
APP = ROOT / "Titonium/App.qml"
CHECK = ROOT / "scripts/check.sh"
EN = ROOT / "config/i18n/en.json"
VI = ROOT / "config/i18n/vi.json"


def main() -> int:
    errors: list[str] = []
    if not SERVICE.is_file():
        errors.append("missing CenterActivityService.qml")
    else:
        source = SERVICE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton",
            "CenterActivityRules.upsert",
            "CenterActivityRules.remove",
            "CenterActivityRules.advance",
            "CenterActivityRules.current",
            "CenterActivityRules.remainingMinutes",
            "CenterAttentionService.hasTransient",
            "readonly property var presentation:",
            "readonly property bool hasActivity:",
            "readonly property bool showingFocus:",
            "readonly property int activeCount:",
            "function upsert(descriptor: var): bool",
            "function remove(activityId: string): bool",
            "function snapshot(): string",
            "function activate(): void",
            "repeat: false",
        ):
            if fragment not in source:
                errors.append(f"CenterActivityService missing contract: {fragment}")
        if source.count("Timer {") != 1:
            errors.append("CenterActivityService must own exactly one Timer")
        for forbidden in (
            "Process {", "FileView {", "repeat: true", "/proc", "pgrep",
            "function upsert(descriptor: var, priority", "function upsert(descriptor: var, ttl",
        ):
            if forbidden in source:
                errors.append(f"CenterActivityService has forbidden behavior: {forbidden}")
        if re.search(r'command\s*:', source):
            errors.append("CenterActivityService must not execute commands")

    if not RULES.is_file():
        errors.append("missing CenterActivityRules.js")

    qmldir = QMLDIR.read_text(encoding="utf-8")
    if "singleton CenterActivityService 1.0 CenterActivityService.qml" not in qmldir:
        errors.append("Center qmldir missing CenterActivityService singleton")

    app = APP.read_text(encoding="utf-8")
    for fragment in (
        "CenterActivityService.activate()",
        "function activityState(): string { return CenterActivityService.snapshot(); }",
    ):
        if fragment not in app:
            errors.append(f"App missing Center Activity contract: {fragment}")

    check = CHECK.read_text(encoding="utf-8")
    for fragment in (
        'node "$project_root/scripts/check_center_activity_rules.js"',
        'python3 "$project_root/scripts/check_center_activity.py"',
    ):
        if fragment not in check:
            errors.append(f"check.sh missing Center Activity gate: {fragment}")

    required_keys = (
        "menubar.center.activity.job_progress",
        "menubar.center.activity.timer_minutes",
        "menubar.center.activity.timer_under_minute",
    )
    en = json.loads(EN.read_text(encoding="utf-8"))["strings"]
    vi = json.loads(VI.read_text(encoding="utf-8"))["strings"]
    for key in required_keys:
        if key not in en or key not in vi:
            errors.append(f"missing Center Activity locale key: {key}")

    if errors:
        print("FAIL Center Activity architecture")
        for error in errors:
            print(error)
        return 1
    print("PASS Center Activity singleton and event-driven scheduler")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
