#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "Titonium/Services/SystemMonitor"
SERVICE = SERVICE_ROOT / "SystemMonitorService.qml"
QMLDIR = SERVICE_ROOT / "qmldir"


def main() -> int:
    errors: list[str] = []
    if not SERVICE.is_file():
        errors.append("missing SystemMonitorService.qml")
    else:
        source = SERVICE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton",
            "import Quickshell.Io",
            "readonly property bool active:",
            "readonly property bool live:",
            "readonly property double hotSampleAt:",
            "readonly property var snapshot:",
            "readonly property var processes:",
            "readonly property bool processesStale:",
            "function start(): bool",
            "function stop(): bool",
            "function refreshDue(now: double): void",
            "function state(): string",
            "property Timer scheduler: Timer",
            "repeat: false",
            "property int generation:",
            'command: ["ps", "-eo", "pid=,comm=,%cpu=,rss="]',
            'command: ["df", "-P", "-B1",',
            'command: ["find", "-L", "/sys/class/drm",',
            'path: "/proc/stat"',
            'path: "/proc/meminfo"',
            'path: "/proc/net/dev"',
            "SystemMonitorRules.parseCpuStat",
            "SystemMonitorRules.parseMeminfo",
            "SystemMonitorRules.parseNetDev",
            "SystemMonitorRules.parseProcesses",
            "SystemMonitorRules.parseDf",
            "SystemMonitorRules.selectSensorPaths",
            "root.generation++",
            "root.psProcess.running = false",
            "root.dfProcess.running = false",
            "root.discoveryProcess.running = false",
        ):
            if fragment not in source:
                errors.append(f"SystemMonitorService missing contract: {fragment}")
        if source.count("Timer {") != 1:
            errors.append("SystemMonitorService must own exactly one scheduler Timer")
        if source.count("Process {") != 3:
            errors.append("SystemMonitorService must own exactly discovery, ps and df Processes")
        if source.count("FileView {") < 9:
            errors.append("SystemMonitorService must own proc and optional sensor FileViews")
        for forbidden in (
            "repeat: true", "Quickshell.execDetached", "notify-send",
            "qs.Titonium.Services.Hyprland", "DBus", "python", "python3",
            "cargo", "go run", "totalPower", "systemPower",
        ):
            if forbidden in source:
                errors.append(f"SystemMonitorService has forbidden dependency: {forbidden}")

    if not QMLDIR.is_file():
        errors.append("missing SystemMonitor qmldir")
    elif QMLDIR.read_text(encoding="utf-8") != (
        "module qs.Titonium.Services.SystemMonitor\n"
        "singleton SystemMonitorService 1.0 SystemMonitorService.qml\n"
    ):
        errors.append("SystemMonitor qmldir must export only its singleton")

    for path in (ROOT / "Titonium/Bar").rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        for forbidden in ("Process {", "FileView {", 'path: "/proc/', 'path: "/sys/'):
            if forbidden in source:
                errors.append(
                    f"Bar presentation owns monitor runtime: {path.relative_to(ROOT)}: {forbidden}"
                )

    if errors:
        print("FAIL System Monitor architecture")
        print("\n".join(errors))
        return 1
    print("PASS on-demand System Monitor service ownership and lifecycle")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
