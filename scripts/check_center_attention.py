#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CENTER = ROOT / "Titonium/Services/Center"
SERVICE = CENTER / "CenterAttentionService.qml"
FOCUS_STORE = CENTER / "CenterFocusStore.qml"
QMLDIR = CENTER / "qmldir"
APP = ROOT / "Titonium/App.qml"


def main() -> int:
    errors: list[str] = []
    for path in (SERVICE, FOCUS_STORE, QMLDIR):
        if not path.is_file():
            errors.append(f"missing Center service contract: {path.relative_to(ROOT)}")

    if SERVICE.is_file():
        source = SERVICE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton",
            "readonly property var presentation:",
            "readonly property var indicators:",
            "readonly property bool hasTransient:",
            "function publish(event: var): bool",
            "function acknowledge(eventId: string): bool",
            "function clear(eventId: string): bool",
            "function clearSource(source: string): bool",
            "function setIndicator(id: string, icon: string, accessibleName: string, active: bool): bool",
            "function snapshot(): string",
            "CenterAttentionRules.publish",
            "CenterAttentionRules.expire",
            "scheduledGeneration",
            "scheduledId",
            "repeat: false",
        ):
            if fragment not in source:
                errors.append(f"CenterAttentionService missing contract: {fragment}")
        if source.count("Timer {") != 1:
            errors.append("CenterAttentionService must own exactly one expiry Timer")
        for forbidden in (
            "repeat: true",
            "Process {",
            "FileView {",
            "import qs.Titonium.Bar",
            "import qs.Titonium.Overlays",
        ):
            if forbidden in source:
                errors.append(f"CenterAttentionService has forbidden dependency: {forbidden}")
        if re.search(r"function\s+publish\([^)]*(?:priority|ttl)", source, re.IGNORECASE):
            errors.append("Center publishers must not accept raw priority or TTL")

    if FOCUS_STORE.is_file():
        source = FOCUS_STORE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton",
            'Quickshell.dataPath("center/',
            'readonly property string focusPath: Quickshell.dataPath("center/daily-focus.md")',
            'readonly property string promptsPath: Quickshell.dataPath("center/focus-prompts.txt")',
            "readonly property string text:",
            "readonly property bool ready:",
            "function openScratchpad(): bool",
            "function snapshot(): string",
            "watchChanges: true",
            "blockLoading: true",
            "printErrors: false",
            'command: ["stat", "-c", "%Y", root.focusPath]',
            'command: ["mkdir", "-p", root.centerPath]',
            'command: ["xdg-open", root.focusPath]',
            "StdioCollector {",
            "onFileChanged:",
            "CenterAttentionService.publish",
            "repeat: false",
        ):
            if fragment not in source:
                errors.append(f"CenterFocusStore missing contract: {fragment}")
        if source.count("FileView {") != 2:
            errors.append("CenterFocusStore must own exactly two reactive FileViews")
        if source.count("Timer {") != 1:
            errors.append("CenterFocusStore must own exactly one midnight Timer")
        for forbidden in (
            'command: "',
            '["sh", "-c"',
            '["bash", "-c"',
            "repeat: true",
            "Component.onCompleted: root.openScratchpad",
        ):
            if forbidden in source:
                errors.append(f"CenterFocusStore has forbidden behavior: {forbidden}")

    if QMLDIR.is_file():
        qmldir = QMLDIR.read_text(encoding="utf-8")
        for fragment in (
            "module qs.Titonium.Services.Center",
            "singleton CenterAttentionService 1.0 CenterAttentionService.qml",
            "singleton CenterFocusStore 1.0 CenterFocusStore.qml",
        ):
            if fragment not in qmldir:
                errors.append(f"Center qmldir missing contract: {fragment}")

    app = APP.read_text(encoding="utf-8")
    if app.count("import qs.Titonium.Services.Center") != 1:
        errors.append("App must import the Center service module exactly once")

    bar_root = ROOT / "Titonium/Bar"
    for path in bar_root.rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        for forbidden in ("CenterAttentionRules", "Process {", "FileView {"):
            if forbidden in source:
                errors.append(f"Bar view owns Center runtime logic: {path.relative_to(ROOT)}: {forbidden}")

    if errors:
        print("FAIL Center attention architecture")
        for error in errors:
            print(error)
        return 1
    print("PASS Center attention singleton, expiry and view boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
