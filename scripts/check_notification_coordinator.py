#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NOTIFICATIONS = ROOT / "Titonium/Services/Notifications"
COORDINATOR = NOTIFICATIONS / "NotificationCoordinator.qml"
RULES = NOTIFICATIONS / "NotificationCoordinatorRules.js"
SERVICE = NOTIFICATIONS / "NotificationService.qml"
QMLDIR = NOTIFICATIONS / "qmldir"
BRIDGE = ROOT / "Titonium/Orchestration/NotificationBridge.qml"
BRIDGE_QMLDIR = ROOT / "Titonium/Orchestration/qmldir"
APP = ROOT / "Titonium/App.qml"
JOB = ROOT / "Titonium/Services/Center/CenterJobService.qml"
TIMER = ROOT / "Titonium/Services/Center/CenterTimerService.qml"


def require(errors: list[str], source: str, label: str, fragments: tuple[str, ...]) -> None:
    for fragment in fragments:
        if fragment not in source:
            errors.append(f"{label} missing contract: {fragment}")


def main() -> int:
    errors: list[str] = []
    for path in (COORDINATOR, RULES, BRIDGE):
        if not path.is_file():
            errors.append(f"missing notification coordinator contract: {path.relative_to(ROOT)}")

    coordinator = COORDINATOR.read_text(encoding="utf-8") if COORDINATOR.is_file() else ""
    require(errors, coordinator, "NotificationCoordinator", (
        "pragma Singleton",
        'import "NotificationRules.js" as NotificationRules',
        'import "NotificationCoordinatorRules.js" as CoordinatorRules',
        "property var coordinatorState: CoordinatorRules.setPresentationEligible(",
        "CoordinatorRules.initialState(), false, 0)",
        "readonly property var history:",
        "readonly property var toasts:",
        "readonly property var unread:",
        "readonly property var currentCritical:",
        "readonly property int criticalQueueCount:",
        "function publish(descriptor: var): bool",
        "function publishInternal(event: var): bool",
        "function read(key: string): bool",
        "function dismiss(key: string): bool",
        "function dismissAll(): int",
        "function action(key: string, actionId: string): bool",
        "function completeCritical(key: string): bool",
        "function setCriticalPresentationEligible(eligible: bool): bool",
        "function reclassify(): bool",
        "function retire(key: string, reason: string): bool",
        "NotificationRules.resolvePolicy",
        "CoordinatorRules.reclassify",
        "NotificationService.dismiss(key)",
        "NotificationService.invokeAction(key, actionId)",
    ))
    if coordinator.count("Timer {") != 0:
        errors.append("NotificationCoordinator must not own a presentation deadline Timer")
    for forbidden_countdown in ("deadlineGeneration", "scheduledCriticalKey",
                                "scheduledCriticalDeadline", "pauseCritical",
                                "resumeCritical", "deadlineMatches"):
        if forbidden_countdown in coordinator:
            errors.append(
                f"NotificationCoordinator owns forbidden presentation clock state: {forbidden_countdown}")
    for forbidden in ("NotificationServer {", "Process {", "FileView {"):
        if forbidden in coordinator:
            errors.append(f"NotificationCoordinator owns forbidden native behavior: {forbidden}")

    service = SERVICE.read_text(encoding="utf-8")
    require(errors, service, "NotificationService", (
        "signal descriptorPublished(var descriptor)",
        "signal descriptorRetired(string key, string reason)",
        "root.descriptorPublished(item)",
        "function retireNativeNotification(key: string, reason: var): void",
        "notification.closed.connect(reason =>",
        "root.retireNativeNotification(key, reason)",
    ))
    for center_import in re.findall(r"^import\s+qs\.Titonium\.Services\.Center.*$", service,
                                    re.MULTILINE):
        errors.append(f"NotificationService must remain Center-independent: {center_import}")

    job = JOB.read_text(encoding="utf-8")
    timer = TIMER.read_text(encoding="utf-8")
    for source, label in ((job, "CenterJobService"), (timer, "CenterTimerService")):
        require(errors, source, label, ("signal notificationPublished(var notification)",))
        if "import qs.Titonium.Services.Notifications" in source:
            errors.append(f"{label} must emit values without importing Notifications")
    require(errors, job, "CenterJobService", (
        'result.event.kind === "job_failed"',
        'result.event.kind === "job_requires_action"',
        "root.notificationPublished(result.event)",
    ))
    require(errors, timer, "CenterTimerService", (
        'event.kind === "timer_finished"',
        "root.notificationPublished(publishedEvent)",
    ))

    bridge = BRIDGE.read_text(encoding="utf-8") if BRIDGE.is_file() else ""
    require(errors, bridge, "NotificationBridge", (
        "import qs.Titonium.Services.Center",
        "import qs.Titonium.Services.Notifications",
        "target: NotificationService",
        "target: CenterJobService",
        "target: CenterTimerService",
        "NotificationCoordinator.publish(descriptor)",
        "NotificationCoordinator.retire(key, reason)",
        "NotificationCoordinator.publishInternal(notification)",
    ))
    if "onDescriptorRemoved" in bridge or "NotificationCoordinator.withdraw" in bridge:
        errors.append("native close must retire presentation instead of deleting coordinator history")
    if any(token in bridge for token in ("CenterSurfaceController", "SurfaceRouter", "PanelWindow")):
        errors.append("NotificationBridge must coordinate values, not own Center/UI presentation")

    qmldir = QMLDIR.read_text(encoding="utf-8")
    require(errors, qmldir, "Notifications qmldir", (
        "singleton NotificationCoordinator 1.0 NotificationCoordinator.qml",
        "singleton NotificationService 1.0 NotificationService.qml",
    ))
    orchestration_qmldir = BRIDGE_QMLDIR.read_text(encoding="utf-8")
    require(errors, orchestration_qmldir, "Orchestration qmldir", (
        "NotificationBridge 1.0 NotificationBridge.qml",
    ))
    require(errors, APP.read_text(encoding="utf-8"), "App composition", (
        "NotificationBridge {}",
    ))

    if errors:
        print("FAIL notification coordinator and bridge contract")
        print("\n".join(errors))
        return 1
    print("PASS notification coordinator and value-only orchestration bridge")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
