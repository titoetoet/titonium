#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "Titonium/Services/SystemMonitor"
SERVICE = SERVICE_ROOT / "SystemMonitorService.qml"
QMLDIR = SERVICE_ROOT / "qmldir"
NOTCH_ROOT = ROOT / "Titonium/Bar/notch"
NOTCH_COORDINATOR = NOTCH_ROOT / "CenterNotchCoordinator.qml"
APP = ROOT / "Titonium/App.qml"
ACCEPTANCE = ROOT / "scripts/system_monitor_acceptance.sh"
PRESENTATION_FILES = (
    "SystemProcessRow.qml", "SystemMonitoringPage.qml",
)


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
            "readonly property var cpuHistory:",
            "readonly property var cpuTemperatureHistory:",
            "cpuHistoryState",
            "slice(-60)",
            "readonly property int historySampleIntervalMs: 1000",
            "readonly property int storageSampleIntervalMs: 5000",
            "function start(): bool",
            "function stop(): bool",
            "function refreshDue(now: double): void",
            "function state(): string",
            "readonly property int hotSampleIntervalMs: 1000",
            "readonly property int processSampleIntervalMs: 2000",
            "property Timer scheduler: Timer",
            "repeat: false",
            "property int generation:",
            'command: ["ps", "-eo", "pid=,comm=,%cpu=,rss="]',
            'command: ["find", "-L", "/sys/class/drm",',
            'command: ["lspci", "-mm", "-d", "::0300"]',
            'command: ["df", "-B1", "--output=size,used", "/"]',
            'path: "/proc/stat"',
            'path: "/proc/meminfo"',
            'path: "/proc/cpuinfo"',
            "path: root.sensorPaths.gpuClock || \"\"",
            "SystemMonitorRules.parseCpuStat",
            "SystemMonitorRules.parseMeminfo",
            "SystemMonitorRules.parseCpuName",
            "SystemMonitorRules.parseAverageCpuFrequencyGhz",
            "SystemMonitorRules.parseGpuClock",
            "SystemMonitorRules.parseGpuName",
            "SystemMonitorRules.parseProcesses",
            "SystemMonitorRules.parseStorageCapacity",
            "SystemMonitorRules.selectSensorPaths",
            "root.generation++",
            "root.psProcess.running = false",
            "root.discoveryProcess.running = false",
            "root.gpuInfoProcess.running = false",
            "root.storageProcess.running = false",
            "root.snapshotState = Object.freeze({",
            "root.processesState = Object.freeze([])",
            "root.cpuHistoryState = Object.freeze([])",
            "root.liveState = root.active && cpuPercent !== null",
        ):
            if fragment not in source:
                errors.append(f"SystemMonitorService missing contract: {fragment}")
        if source.count("Timer {") != 1:
            errors.append("SystemMonitorService must own exactly one scheduler Timer")
        if source.count("Process {") != 4:
            errors.append("SystemMonitorService must own exactly discovery, GPU info, ps and storage Processes")
        if source.count("FileView {") < 8:
            errors.append("SystemMonitorService must own proc and optional sensor FileViews")
        for forbidden in (
            "SystemMonitorRules.parseNetDev", "SystemMonitorRules.networkRate",
            "SystemMonitorRules.parseDf", "snapshot.disk", "snapshot.network",
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

    for name in PRESENTATION_FILES:
        path = NOTCH_ROOT / name
        if not path.is_file():
            errors.append(f"missing Center Monitoring presentation: {name}")
            continue
        source = path.read_text(encoding="utf-8")
        for forbidden in ("Process {", "FileView {", "Timer {", "execDetached", "Date.now()", "/proc", "/sys"):
            if forbidden in source:
                errors.append(f"{name} owns forbidden monitor runtime: {forbidden}")
        for fragment in ("import qs.Titonium.Shared as Shared", "import qs.Titonium.Theme"):
            if fragment not in source:
                errors.append(f"{name} missing themed presentation contract: {fragment}")

    page = NOTCH_ROOT / "SystemMonitoringPage.qml"
    if page.is_file():
        source = page.read_text(encoding="utf-8")
        for forbidden in ("SystemMetricBlock", "CenterActivityService", "snapshot.disk", "snapshot.network",
                "center_notch.monitoring.process_running", "center_notch.monitoring.process_status"):
            if forbidden in source:
                errors.append(f"SystemMonitoringPage retains removed presentation: {forbidden}")
        for fragment in (
            "import qs.Titonium.Services.SystemMonitor",
            "GridLayout {", "columns: 2",
            "model: SystemMonitorService.processes",
            "id: hardwarePanel", "id: processesPanel",
            "SystemMonitorService.cpuHistory",
            "SystemMonitorService.cpuTemperatureHistory",
            "preferredRendererType: Shape.SoftwareRenderer",
            "PathPolyline",
            "center_notch.monitoring.utilization",
            "Layout.minimumWidth: 0",
            "SystemMonitorService.snapshot.cpu",
            "SystemMonitorService.snapshot.ram",
            "SystemMonitorService.snapshot.gpu",
            "SystemMonitorService.snapshot.vram",
            "SystemMonitorService.snapshot.storage",
            "id: gpuBar",
            'name: "format_list_numbered"', 'name: "developer_board"',
            'name: "memory_alt"',
            'name: "storage"',
            "center_notch.monitoring.gpu_clock",
            "SystemMonitorService.snapshot.cpu?.name",
            "SystemMonitorService.snapshot.gpu?.name",
            "center_notch.monitoring.top_processes",
        ):
            if fragment not in source:
                errors.append(f"SystemMonitoringPage missing contract: {fragment}")
        for forbidden in (
            "SystemMonitorService.start()", "SystemMonitorService.stop()",
            "Canvas {", "animatedCpuVal", "animatedRamVal", "animatedGpuVal",
        ):
            if forbidden in source:
                errors.append(f"SystemMonitoringPage must not own monitor lifecycle: {forbidden}")

    coordinator_source = NOTCH_COORDINATOR.read_text(encoding="utf-8")
    for fragment in (
        "import qs.Titonium.Services.SystemMonitor",
        "function syncMonitoringLifecycle(): void",
        "onActiveChanged: root.syncMonitoringLifecycle()",
        "onRequestedPageChanged: root.syncMonitoringLifecycle()",
        "SystemMonitorService.start()",
        "SystemMonitorService.stop()",
    ):
        if fragment not in coordinator_source:
            errors.append(f"CenterNotchCoordinator missing monitor lifecycle: {fragment}")

    notch_qmldir = NOTCH_ROOT / "qmldir"
    if notch_qmldir.is_file():
        exports = notch_qmldir.read_text(encoding="utf-8")
        for name in PRESENTATION_FILES:
            component = name.removesuffix(".qml")
            if f"{component} 1.0 {name}" not in exports:
                errors.append(f"Center notch qmldir missing {component}")

    app_source = APP.read_text(encoding="utf-8")
    for fragment in (
        "import qs.Titonium.Services.SystemMonitor",
        "function monitorState(): string { return SystemMonitorService.state(); }",
    ):
        if fragment not in app_source:
            errors.append(f"App missing System Monitor diagnostics: {fragment}")
    for forbidden in ("SystemMonitorService.start()", "SystemMonitorService.stop()"):
        if forbidden in app_source:
            errors.append(f"App IPC must not own monitor lifecycle: {forbidden}")

    if not ACCEPTANCE.is_file():
        errors.append("missing system_monitor_acceptance.sh")
    else:
        acceptance_source = ACCEPTANCE.read_text(encoding="utf-8")
        if ACCEPTANCE.stat().st_mode & 0o111 == 0:
            errors.append("System Monitor acceptance must be executable")
        for fragment in (
            "set -euo pipefail", "centerNotch open monitoring",
            "center monitorState", "centerNotch page notifications",
            "before_git", "before_live", "before_dotfiles",
            "Configuration Loaded", "trap cleanup EXIT",
            "production_was_running", "qs -d -p",
        ):
            if fragment not in acceptance_source:
                errors.append(f"System Monitor acceptance missing contract: {fragment}")

    if errors:
        print("FAIL System Monitor architecture")
        print("\n".join(errors))
        return 1
    print("PASS on-demand System Monitor service ownership and lifecycle")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
