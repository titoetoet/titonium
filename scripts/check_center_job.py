#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CENTER = ROOT / "Titonium/Services/Center"
SERVICE = CENTER / "CenterJobService.qml"
RULES = CENTER / "CenterJobRules.js"
QMLDIR = CENTER / "qmldir"
APP = ROOT / "Titonium/App.qml"
ACCEPTANCE = ROOT / "scripts/center_job_acceptance.sh"


def main() -> int:
    errors: list[str] = []

    for path in (SERVICE, RULES, QMLDIR, ACCEPTANCE):
        if not path.is_file():
            errors.append(f"missing Job contract: {path.relative_to(ROOT)}")

    if SERVICE.is_file():
        source = SERVICE.read_text(encoding="utf-8")
        for fragment in (
            "pragma Singleton",
            "readonly property var jobs:",
            "readonly property int activeCount:",
            "function start(id: string, label: string, importance: string): string",
            "function progress(id: string, percent: string, label: string): string",
            "function complete(id: string, summary: string): string",
            "function fail(id: string, summary: string): string",
            "function requireAction(id: string, summary: string): string",
            "function clear(id: string): string",
            "function snapshot(): string",
            "function activate(): void",
            "CenterJobRules.start",
            "CenterJobRules.progress",
            "CenterJobRules.complete",
            "CenterJobRules.fail",
            "CenterJobRules.requireAction",
            "CenterJobRules.clear",
            "CenterAttentionService.publish",
            "CenterAttentionService.clear",
            "CenterAttentionService.setIndicator",
            '"menubar.center.indicator.jobs"',
            "function syncActivity(job: var): void",
            "function removeActivity(id: string): void",
            "CenterActivityService.upsert({",
            "CenterActivityService.remove(\"job:\" + id.trim())",
            '"id": "job:" + job.id',
            '"source": "job"',
            '"label": job.label',
            '"icon": "work"',
            '"importance": job.importance',
            '"progress": job.percent',
            '"deadline": 0',
            '"updatedAt": job.changedAt',
        ):
            if fragment not in source:
                errors.append(f"CenterJobService missing contract: {fragment}")
        for forbidden in (
            "Timer {",
            "Process {",
            "FileView {",
            "priority:",
            "ttl:",
            "import qs.Titonium.Bar",
            "import qs.Titonium.Overlays",
            "hyprctl",
            "ps ",
            "/proc",
        ):
            if forbidden in source:
                errors.append(f"CenterJobService has forbidden ownership: {forbidden}")

    if RULES.is_file():
        source = RULES.read_text(encoding="utf-8")
        for fragment in (
            "function initialState()",
            "function start(",
            "function progress(",
            "function complete(",
            "function fail(",
            "function requireAction(",
            "function clear(",
        ):
            if fragment not in source:
                errors.append(f"CenterJobRules missing contract: {fragment}")
        for forbidden in ("Date.now(", "CenterAttentionService", "I18n", "Process {", "Timer {"):
            if forbidden in source:
                errors.append(f"CenterJobRules owns runtime behavior: {forbidden}")

    if QMLDIR.is_file() and (
        "singleton CenterJobService 1.0 CenterJobService.qml"
        not in QMLDIR.read_text(encoding="utf-8")
    ):
        errors.append("Center qmldir missing CenterJobService singleton")

    app = APP.read_text(encoding="utf-8")
    for fragment in (
        "CenterJobService.activate()",
        'target: "job"',
        "function state(): string",
        "function start(id: string, label: string, importance: string): string",
        "function progress(id: string, percent: string, label: string): string",
        "function complete(id: string, summary: string): string",
        "function fail(id: string, summary: string): string",
        "function requireAction(id: string, summary: string): string",
        "function clear(id: string): string",
        "CenterJobService.snapshot()",
    ):
        if fragment not in app:
            errors.append(f"App missing Job lifecycle/IPC contract: {fragment}")
    job_ipc = re.search(
        r'IpcHandler\s*\{\s*target:\s*"job"(?P<body>.*?)(?=\n\s*IpcHandler\s*\{|\Z)',
        app,
        re.DOTALL,
    )
    if job_ipc:
        body = job_ipc.group("body")
        for forbidden in ("priority", "ttl", "publish(", "clearSource("):
            if forbidden in body:
                errors.append(f"Job IPC exposes arbitration internals: {forbidden}")

    if ACCEPTANCE.is_file():
        if ACCEPTANCE.stat().st_mode & 0o111 == 0:
            errors.append("Job acceptance must be executable")
        source = ACCEPTANCE.read_text(encoding="utf-8")
        for fragment in (
            "job state",
            "job start",
            "job progress",
            "job complete",
            "job fail",
            "job requireAction",
            "job clear",
            "center state",
            'runtime_root="$test_dir/runtime"',
            'qs -n -p "$runtime_root"',
            "cp -a --",
            '"activeCount"',
            "job_requires_action",
            "before_git",
            "before_live",
            "before_dotfiles",
            "Configuration Loaded",
        ):
            if fragment not in source:
                errors.append(f"Job acceptance missing contract: {fragment}")

    if errors:
        print("FAIL Center Job architecture")
        print("\n".join(errors))
        return 1
    print("PASS explicit Center Job service and IPC boundaries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
