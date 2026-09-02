#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CENTER = ROOT / "Titonium/Services/Center"
SERVICE = CENTER / "CenterTimerService.qml"
RULES = CENTER / "CenterTimerRules.js"
QMLDIR = CENTER / "qmldir"
APP = ROOT / "Titonium/App.qml"
ACCEPTANCE = ROOT / "scripts/center_timer_acceptance.sh"


def main() -> int:
    errors: list[str] = []

    for path in (SERVICE, RULES, QMLDIR, ACCEPTANCE):
        if not path.is_file():
            errors.append(f"missing Timer contract: {path.relative_to(ROOT)}")

    if SERVICE.is_file():
        source = SERVICE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton",
            "readonly property var timers:",
            "readonly property int activeCount:",
            "function start(id: string, durationSeconds: int, label: string): bool",
            "function cancel(id: string): bool",
            "function acknowledge(id: string): bool",
            "function snapshot(): string",
            "function activate(): void",
            "CenterTimerRules.start",
            "CenterTimerRules.cancel",
            "CenterTimerRules.advance",
            "CenterTimerRules.nextWake",
            "id.trim()",
            "CenterAttentionService.publish",
            "CenterAttentionService.clear",
            "CenterAttentionService.acknowledge",
            "CenterAttentionService.setIndicator",
            '"menubar.center.indicator.timer"',
            '"menubar.center.timer.five_minutes"',
            '"menubar.center.timer.one_minute"',
            '"menubar.center.timer.finished"',
            "repeat: false",
            "function syncActivity(timer: var, now: double): void",
            "function removeActivity(id: string): void",
            "function removeMissingActivities(previousState: var, nextState: var): void",
            "CenterActivityService.upsert({",
            "CenterActivityService.remove(\"timer:\" + id.trim())",
            '"id": "timer:" + timer.id',
            '"source": "timer"',
            '"label": timer.label',
            '"icon": "timer"',
            '"importance": "normal"',
            '"progress": -1',
            '"deadline": timer.deadline',
            '"updatedAt": now',
        ):
            if fragment not in source:
                errors.append(f"CenterTimerService missing contract: {fragment}")
        if source.count("Timer {") != 1:
            errors.append("CenterTimerService must own exactly one milestone Timer")
        for forbidden in (
            "repeat: true",
            "Process {",
            "FileView {",
            "setInterval",
            "priority:",
            "ttl:",
            "import qs.Titonium.Bar",
            "import qs.Titonium.Overlays",
        ):
            if forbidden in source:
                errors.append(f"CenterTimerService has forbidden dependency: {forbidden}")

    if RULES.is_file():
        source = RULES.read_text(encoding="utf-8")
        for fragment in (
            "function initialState()",
            "function start(",
            "function cancel(",
            "function advance(",
            "function nextWake(",
        ):
            if fragment not in source:
                errors.append(f"CenterTimerRules missing contract: {fragment}")
        for forbidden in ("Timer {", "Date.now(", "CenterAttentionService", "I18n"):
            if forbidden in source:
                errors.append(f"CenterTimerRules owns runtime behavior: {forbidden}")

    if QMLDIR.is_file() and (
        "singleton CenterTimerService 1.0 CenterTimerService.qml"
        not in QMLDIR.read_text(encoding="utf-8")
    ):
        errors.append("Center qmldir missing CenterTimerService singleton")

    app = (ROOT / "Titonium/Orchestration/ServiceBootstrap.qml").read_text(encoding="utf-8")
    app += (ROOT / "Titonium/Ipc/CenterIpc.qml").read_text(encoding="utf-8")
    for fragment in (
        "CenterTimerService.activate()",
        'target: "timer"',
        "function state(): string",
        "function start(id: string, durationSeconds: int, label: string): string",
        "function cancel(id: string): string",
        "function acknowledge(id: string): string",
        "CenterTimerService.snapshot()",
    ):
        if fragment not in app:
            errors.append(f"App missing Timer lifecycle/IPC contract: {fragment}")
    timer_ipc = re.search(
        r'IpcHandler\s*\{\s*target:\s*"timer"(?P<body>.*?)(?=\n\s*(?:property\s+IpcHandler\s+\w+\s*:\s*)?IpcHandler\s*\{|\Z)',
        app,
        re.DOTALL,
    )
    if timer_ipc:
        body = timer_ipc.group("body")
        for forbidden in ("priority", "ttl", "publish(", "clearSource("):
            if forbidden in body:
                errors.append(f"Timer IPC exposes arbitration internals: {forbidden}")

    for locale in ("en", "vi"):
        path = ROOT / f"config/i18n/{locale}.json"
        strings = json.loads(path.read_text(encoding="utf-8")).get("strings", {})
        for key in (
            "menubar.center.indicator.timer",
            "menubar.center.timer.five_minutes",
            "menubar.center.timer.one_minute",
            "menubar.center.timer.finished",
        ):
            if key not in strings:
                errors.append(f"{locale}.json missing Timer locale key: {key}")

    if ACCEPTANCE.is_file():
        if ACCEPTANCE.stat().st_mode & 0o111 == 0:
            errors.append("Timer acceptance must be executable")
        source = ACCEPTANCE.read_text(encoding="utf-8")
        for fragment in (
            "timer state",
            "timer start",
            "timer cancel",
            "timer acknowledge",
            "center state",
            '"activeCount"',
            "timer_finished",
            "before_git",
            "before_live",
            "before_dotfiles",
            "Configuration Loaded",
        ):
            if fragment not in source:
                errors.append(f"Timer acceptance missing contract: {fragment}")

    if errors:
        print("FAIL Center Timer architecture")
        print("\n".join(errors))
        return 1
    print("PASS event-driven Center Timer service and IPC boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
