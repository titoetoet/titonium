#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CENTER = ROOT / "Titonium/Services/Center"
SERVICE = CENTER / "CenterAttentionService.qml"
FOCUS_STORE = CENTER / "CenterFocusStore.qml"
QMLDIR = CENTER / "qmldir"
APP = ROOT / "Titonium/App.qml"
CENTER_VIEW = ROOT / "Titonium/Bar/islands/CenterIsland.qml"
CENTER_OVERVIEW = ROOT / "Titonium/Bar/notch/OverviewPage.qml"
ACCEPTANCE = ROOT / "scripts/center_attention_acceptance.sh"


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
            "CenterAttentionRules.expiryRequest",
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
    for fragment in (
        'target: "center"',
        "function state(): string { return CenterAttentionService.snapshot(); }",
        "function focusState(): string { return CenterFocusStore.snapshot(); }",
    ):
        if fragment not in app:
            errors.append(f"App missing read-only Center IPC contract: {fragment}")
    center_ipc_match = re.search(
        r'IpcHandler\s*\{\s*target:\s*"center"(?P<body>.*?)(?=\n\s*IpcHandler\s*\{|\Z)',
        app,
        re.DOTALL,
    )
    if center_ipc_match:
        body = center_ipc_match.group("body")
        for forbidden in ("openScratchpad", "publish(", "acknowledge(", "clear(", "start(", "cancel("):
            if forbidden in body:
                errors.append(f"Center IPC exposes a mutating method: {forbidden}")

    if CENTER_VIEW.is_file():
        source = CENTER_VIEW.read_text(encoding="utf-8")
        for fragment in (
            "CenterAttentionService.presentation",
            "CenterAttentionService.indicators",
            "CenterFocusStore.text",
        ):
            if fragment not in source:
                errors.append(f"Center view missing service projection: {fragment}")
        if "CenterFocusStore.openScratchpad()" in source:
            errors.append("TopBar Center must not bypass the Center Notch")

    if CENTER_OVERVIEW.is_file():
        source = CENTER_OVERVIEW.read_text(encoding="utf-8")
        if source.count("CenterFocusStore.openScratchpad()") != 1:
            errors.append("Center Overview must own exactly one explicit Daily Focus action")
    else:
        errors.append("missing Center Overview Daily Focus owner")

    bar_root = ROOT / "Titonium/Bar"
    for path in bar_root.rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        for forbidden in ("CenterAttentionRules", "Process {", "FileView {"):
            if forbidden in source:
                errors.append(f"Bar view owns Center runtime logic: {path.relative_to(ROOT)}: {forbidden}")

    if not ACCEPTANCE.is_file():
        errors.append("missing scripts/center_attention_acceptance.sh")
    else:
        acceptance = ACCEPTANCE.read_text(encoding="utf-8")
        for fragment in (
            "qs -n -p",
            "XDG_DATA_HOME=",
            "XDG_STATE_HOME=",
            "XDG_CACHE_HOME=",
            "center state",
            "center focusState",
            '"transient"',
            "Focus for today",
            "Tập trung cho hôm nay",
            "hyprctl -j layers",
            "titonium-menubar",
            "DP-1",
            "DP-3",
            "Configuration Loaded",
            "before_git",
            "before_live",
            "before_dotfiles",
        ):
            if fragment not in acceptance:
                errors.append(f"Center acceptance missing read-only contract: {fragment}")
        for forbidden in (
            "center openScratchpad",
            "center publish",
            "center acknowledge",
            "center clear",
            "center timer",
            "center job",
            "xdg-open",
        ):
            if forbidden in acceptance:
                errors.append(f"Center acceptance contains mutation: {forbidden}")

    if errors:
        print("FAIL Center attention architecture")
        for error in errors:
            print(error)
        return 1
    print("PASS Center attention singleton, expiry and view boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
