#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "Titonium/Services/Notifications"
SERVICE = SERVICE_ROOT / "NotificationService.qml"
QMLDIR = SERVICE_ROOT / "qmldir"

REQUIRED = (
    "pragma Singleton",
    "pragma ComponentBehavior: Bound",
    "import Quickshell.Services.Notifications",
    'import "NotificationRules.js" as NotificationRules',
    "property var projectedNotifications: Object.freeze([])",
    "property var toastIds: Object.freeze([])",
    "property var unreadIds: Object.freeze([])",
    "readonly property var notifications: root.projectedNotifications",
    "readonly property var toastNotifications:",
    "readonly property int unreadCount:",
    "readonly property bool hasUnread:",
    "function markAllRead(): bool",
    "function dismiss(id: int): bool",
    "function expireToast(id: int): bool",
    "notification.tracked = true",
    "NotificationRules.descriptor",
    "NotificationRules.upsert",
    "NotificationRules.addToast",
    "NotificationRules.markUnread",
    "NotificationRules.removeId",
    "NotificationServer {",
    "keepOnReload: true",
    "persistenceSupported: true",
    "bodySupported: true",
    "bodyMarkupSupported: false",
    "bodyHyperlinksSupported: false",
    "bodyImagesSupported: false",
    "actionsSupported: false",
    "actionIconsSupported: false",
    "imageSupported: false",
    "inlineReplySupported: false",
    "server.trackedNotifications.values",
    "nativeNotification.dismiss()",
    "readonly property int operationWarningLimit: 3",
    "operationWarningCounts[category]",
    'Logger.warn("notifications"',
)

FORBIDDEN = (
    "Process",
    "FileView",
    "Timer {",
    "execDetached",
    "notify-send",
    "DBus",
)


def public_native_errors(source: str) -> list[str]:
    errors: list[str] = []
    property_pattern = re.compile(
        r"^    (?:(?:readonly|required)\s+)?property\s+[^\n]+$", re.MULTILINE
    )
    for match in property_pattern.finditer(source):
        declaration = match.group(0)
        if re.search(r"\bNotification(?:Server)?\b|:\s*server\b|trackedNotifications", declaration):
            errors.append("notification singleton exposes a native object through a root property")
    function_pattern = re.compile(r"^    function\s+(\w+)\s*\([^)]*\)[^{]*\{", re.MULTILINE)
    for match in function_pattern.finditer(source):
        opening = source.find("{", match.start())
        depth = 0
        end = opening
        for end in range(opening, len(source)):
            if source[end] == "{":
                depth += 1
            elif source[end] == "}":
                depth -= 1
                if depth == 0:
                    break
        block = source[opening:end + 1]
        if re.search(r"\breturn\s+(?:server|notification|nativeNotification)\b", block):
            errors.append(f"notification function returns native state: {match.group(1)}")
    return errors


def validate_gate_fixtures(errors: list[str]) -> None:
    fixtures = (
        "QtObject {\n    property var nativeServer: NotificationServer {}\n}",
        "QtObject {\n    property var nativeList: server.trackedNotifications\n}",
        "QtObject {\n    function leak(): var { return nativeNotification; }\n}",
    )
    for fixture in fixtures:
        if not public_native_errors(fixture):
            errors.append("notification native-exposure matcher missed malicious fixture")


def validate_service(errors: list[str]) -> None:
    if not SERVICE.is_file():
        errors.append("missing NotificationService.qml")
        return
    source = SERVICE.read_text(encoding="utf-8")
    for fragment in REQUIRED:
        if fragment not in source:
            errors.append(f"notification service missing contract: {fragment}")
    for fragment in FORBIDDEN:
        if fragment in source:
            errors.append(f"notification service has forbidden dependency: {fragment}")
    if source.count("NotificationServer {") != 1:
        errors.append("NotificationService must own exactly one NotificationServer")
    errors.extend(public_native_errors(source))


def validate_ownership(errors: list[str]) -> None:
    importers: list[str] = []
    owners: list[str] = []
    for path in (ROOT / "Titonium").rglob("*.qml"):
        source = path.read_text(encoding="utf-8")
        relative = str(path.relative_to(ROOT))
        if "import Quickshell.Services.Notifications" in source:
            importers.append(relative)
        if "NotificationServer {" in source:
            owners.append(relative)
    expected = ["Titonium/Services/Notifications/NotificationService.qml"]
    if importers != expected:
        errors.append("Quickshell Notifications import must belong only to NotificationService")
    if owners != expected:
        errors.append("native NotificationServer ownership must be unique")


def main() -> int:
    errors: list[str] = []
    if not QMLDIR.is_file():
        errors.append("missing Notifications qmldir")
    elif QMLDIR.read_text(encoding="utf-8") != (
        "module Titonium.Services.Notifications\n"
        "singleton NotificationService 1.0 NotificationService.qml\n"
    ):
        errors.append("Notifications qmldir must export only its singleton")
    validate_service(errors)
    validate_ownership(errors)
    validate_gate_fixtures(errors)
    if errors:
        print("FAIL notification service architecture")
        print("\n".join(errors))
        return 1
    print("PASS notification service architecture")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
