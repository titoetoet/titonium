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
CENTER_VIEW = ROOT / "Titonium/Bar/islands/CenterIsland.qml"
ACCEPTANCE = ROOT / "scripts/center_activity_acceptance.sh"
TESTING = ROOT / "docs/TESTING.md"


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
            "readonly property var activities: root.activityState.activities",
            "function upsert(descriptor: var): bool",
            "function remove(activityId: string): bool",
            "function snapshot(): string",
            "property Connections attentionConnections: Connections {",
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
        'bash -n "$project_root/scripts/center_activity_acceptance.sh"',
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

    if not CENTER_VIEW.is_file():
        errors.append("missing CenterIsland.qml")
    else:
        source = CENTER_VIEW.read_text(encoding="utf-8")
        for fragment in (
            "readonly property var eventPresentation: CenterAttentionService.presentation",
            "readonly property var activityPresentation: CenterActivityService.presentation",
            "readonly property var primaryPresentation: root.eventPresentation || root.activityPresentation",
            "root.primaryPresentation.title",
            "CenterFocusStore.text",
            'root.activityPresentation ? "primary" : "secondary"',
            "strong: root.primaryPresentation !== null",
        ):
            if fragment not in source:
                errors.append(f"CenterIsland missing Activity projection: {fragment}")
        for forbidden in (
            "Timer {",
            "Process {",
            "FileView {",
            "CenterActivityService.upsert",
            "CenterActivityService.remove",
            "CenterFocusStore.openScratchpad()",
        ):
            if forbidden in source:
                errors.append(f"CenterIsland owns forbidden runtime behavior: {forbidden}")

    if not ACCEPTANCE.is_file():
        errors.append("missing center_activity_acceptance.sh")
    else:
        if ACCEPTANCE.stat().st_mode & 0o111 == 0:
            errors.append("Center Activity acceptance must be executable")
        source = ACCEPTANCE.read_text(encoding="utf-8")
        for fragment in (
            "set -euo pipefail",
            'runtime_root="$test_dir/runtime"',
            'XDG_DATA_HOME="$test_dir/data"',
            'XDG_STATE_HOME="$test_dir/state"',
            'XDG_CACHE_HOME="$test_dir/cache"',
            'qs -n -p "$runtime_root"',
            "acceptance:activity:",
            "center activityState",
            "center state",
            "job start",
            "job progress",
            "job complete",
            "job clear",
            "timer start",
            "timer cancel",
            "centerNotch open overview",
            "centerNotch close",
            "before_git",
            "before_live",
            "before_dotfiles",
            "Configuration Loaded",
            "trap cleanup EXIT",
        ):
            if fragment not in source:
                errors.append(f"Center Activity acceptance missing contract: {fragment}")
        for forbidden in ("pkill", "/proc", "pgrep"):
            if forbidden in source:
                errors.append(f"Center Activity acceptance has forbidden behavior: {forbidden}")

    docs = TESTING.read_text(encoding="utf-8")
    if "./scripts/center_activity_acceptance.sh" not in docs:
        errors.append("TESTING.md missing Center Activity acceptance command")

    if errors:
        print("FAIL Center Activity architecture")
        for error in errors:
            print(error)
        return 1
    print("PASS Center Activity singleton and event-driven scheduler")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
