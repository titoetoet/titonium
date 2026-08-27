#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ROOT = ROOT / "Titonium/Services/Notifications"
SERVICE = SERVICE_ROOT / "NotificationService.qml"
QMLDIR = SERVICE_ROOT / "qmldir"
PRESENTATION_ROOT = ROOT / "Titonium/Notifications"
APP = ROOT / "Titonium/App.qml"
BELL = ROOT / "Titonium/Bar/widgets/NotificationBell.qml"
PRESENTATION_FILES = {
    "ToastHost.qml": (
        "Variants {",
        "model: ScreenPolicy.screens",
        "ToastWindow {",
    ),
    "ToastWindow.qml": (
        "PanelWindow {",
        'WlrLayershell.namespace: "titonium-notification-toast"',
        "WlrLayershell.exclusionMode: ExclusionMode.Ignore",
        "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None",
        "anchors { top: true; right: true",
        "Metrics.barHeight + Metrics.barSpacing",
        "active: NotificationService.toastNotifications.length > 0",
        "Region { item: stackLoader }",
    ),
    "ToastStack.qml": (
        "width: 360",
        "Repeater {",
        "model: NotificationService.toastNotifications",
        "ToastCard {",
    ),
    "ToastCard.qml": (
        "required property var notification",
        "Shared.SystemIcon",
        "maximumLineCount: 1",
        "maximumLineCount: 3",
        "NotificationService.expireToast(root.notification.id)",
        "NotificationService.dismiss(root.notification.id)",
        "Timer {",
        "interval: 5000",
        "repeat: false",
    ),
    "qmldir": (
        "module Titonium.Notifications",
        "ToastHost 1.0 ToastHost.qml",
    ),
}

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


def qml_block(source: str, start: int) -> str:
    opening = source.find("{", start)
    if opening < 0:
        return ""
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index + 1]
    return ""


def notification_ipc(source: str) -> str:
    for match in re.finditer(r"\bIpcHandler\s*\{", source):
        block = qml_block(source, match.start())
        if re.search(r'\btarget\s*:\s*"notifications"', block):
            return block
    return ""


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


def validate_presentation(errors: list[str]) -> None:
    sources: list[str] = []
    for filename, fragments in PRESENTATION_FILES.items():
        path = PRESENTATION_ROOT / filename
        if not path.is_file():
            errors.append(f"missing notification presentation: Titonium/Notifications/{filename}")
            continue
        source = path.read_text(encoding="utf-8")
        sources.append(source)
        for fragment in fragments:
            if fragment not in source:
                errors.append(f"{filename} missing toast contract: {fragment}")
    feature = "\n".join(sources)
    for fragment in (
        "import Quickshell.Services.Notifications", "Process", "FileView",
        "execDetached", "MultiEffect", "ShaderEffect", "Animation.Infinite",
        "loops: Animation.Infinite",
    ):
        if fragment in feature:
            errors.append(f"notification presentation has forbidden dependency: {fragment}")
    if feature.count("Timer {") != 1:
        errors.append("notification presentation must own exactly one one-shot toast timer")
    for locale in ("en", "vi"):
        catalog_path = ROOT / f"config/i18n/{locale}.json"
        catalog = json.loads(catalog_path.read_text(encoding="utf-8")).get("strings", {})
        for key in (
            "notification.bell.none", "notification.bell.unread",
            "notification.toast.fallback_app", "notification.toast.dismiss",
        ):
            if not isinstance(catalog.get(key), str) or not catalog[key]:
                errors.append(f"{locale} catalog missing notification key: {key}")


def validate_composition(errors: list[str]) -> None:
    app_source = APP.read_text(encoding="utf-8") if APP.is_file() else ""
    if app_source.count("ToastHost {") != 1:
        errors.append("App must compose exactly one ToastHost")
    if "import qs.Titonium.Notifications" not in app_source:
        errors.append("App must import the notification presentation module")
    ipc = notification_ipc(app_source)
    if not ipc:
        errors.append("App must expose the narrow notifications IPC target")
    else:
        methods = set(re.findall(r"^\s*function\s+(\w+)\s*\(", ipc, re.MULTILINE))
        if methods != {"state", "markRead"}:
            errors.append("notifications IPC must expose exactly state and markRead")
        for forbidden in ("dismiss", "action", "inject", "send", "reply"):
            if re.search(rf"\b{forbidden}\w*\s*\(", ipc, re.IGNORECASE):
                errors.append(f"notifications IPC exposes forbidden mutation: {forbidden}")
        for fragment in (
            "NotificationService.notifications.length",
            "NotificationService.toastNotifications.length",
            "NotificationService.unreadCount",
            "NotificationService.markAllRead()",
        ):
            if fragment not in ipc:
                errors.append(f"notifications IPC missing narrow state contract: {fragment}")
    if not BELL.is_file():
        errors.append("missing NotificationBell.qml")
        return
    bell_source = BELL.read_text(encoding="utf-8")
    if "import qs.Titonium.Services.Notifications" not in bell_source:
        errors.append("NotificationBell must consume the descriptor-only notification service")
    for fragment in (
        "width: 24", "height: 24", 'iconName: "notifications"',
        "visible: NotificationService.hasUnread", "width: 6", "height: 6",
        "NotificationService.markAllRead()", "NotificationService.unreadCount",
    ):
        if fragment not in bell_source:
            errors.append(f"NotificationBell missing contract: {fragment}")
    if bell_source.count("NotificationService.markAllRead()") != 1:
        errors.append("Notification Bell must own exactly one read-state mutation")


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
    validate_presentation(errors)
    validate_composition(errors)
    validate_gate_fixtures(errors)
    if errors:
        print("FAIL notification service architecture")
        print("\n".join(errors))
        return 1
    print("PASS notification service architecture")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
