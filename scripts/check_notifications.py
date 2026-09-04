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
        "active: NotificationCoordinator.toasts.length > 0",
        "Region { item: stackLoader }",
    ),
    "ToastStack.qml": (
        "width: 360",
        "Repeater {",
        "model: NotificationCoordinator.toasts",
        "ToastCard {",
    ),
    "ToastCard.qml": (
        "required property var notification",
        "Shared.SystemIcon",
        "maximumLineCount: 1",
        "maximumLineCount: 3",
        "NotificationCoordinator.expireToast(root.notification.key)",
        "NotificationCoordinator.dismiss(root.notification.key)",
        "id: toastTimer",
        "toastTimer.stop()",
        "Timer {",
        "interval: Preferences.notifications.toastDuration",
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
    "property var toastKeys: Object.freeze([])",
    "property var unreadKeys: Object.freeze([])",
    "readonly property var notifications: root.projectedNotifications",
    "readonly property var toastNotifications:",
    "readonly property int unreadCount:",
    "readonly property bool hasUnread:",
    "function markAllRead(): bool",
    "function dismiss(key: string): bool",
    "function dismissAll(): int",
    "function expireToast(key: string): bool",
    "function invokeAction(key: string, actionId: string): bool",
    "function refreshNativeNotification(notification: var): void",
    "function retireNativeNotification(key: string, reason: var): void",
    "notification.tracked = true",
    "NotificationRules.descriptor",
    "NotificationRules.refreshState",
    "NotificationRules.retireState",
    "NotificationRules.warningState",
    "NotificationServer {",
    "keepOnReload: true",
    "persistenceSupported: true",
    "bodySupported: true",
    "bodyMarkupSupported: false",
    "bodyHyperlinksSupported: false",
    "bodyImagesSupported: false",
    "actionsSupported: true",
    "actionIconsSupported: false",
    "imageSupported: false",
    "inlineReplySupported: false",
    "nativeTargets.byKey",
    "nativeNotification.dismiss()",
    "if (root.nativeTargetCurrent(key, nativeNotification)",
    "root.projectedNotifications.some(item => item.key === key)",
    "return known || dismissed",
    "return !!notification && nativeTargets.byKey[key] === notification",
    "nativeAction.invoke()",
    "notification.appNameChanged.connect(refresh)",
    "notification.appIconChanged.connect(refresh)",
    "notification.summaryChanged.connect(refresh)",
    "notification.bodyChanged.connect(refresh)",
    "notification.urgencyChanged.connect(refresh)",
    "notification.desktopEntryChanged.connect(refresh)",
    "notification.actionsChanged.connect(refresh)",
    "notification.closed.connect(reason =>",
    "root.retireNativeNotification(key, reason)",
    "signal descriptorRetired(string key, string reason)",
    "const lifecycleReason = NotificationRules.closeReason(reason)",
    "root.descriptorRetired(key, lifecycleReason)",
    "const keys = root.projectedNotifications.map(item => item.key)",
    "for (let index = 0; index < keys.length; index++)",
    "root.dismiss(keys[index])",
    "readonly property int operationWarningLimit: 3",
    "readonly property bool toastsEnabled:",
    "onToastsEnabledChanged:",
    'Logger.warn("notifications"',
)

FORBIDDEN = (
    "Process",
    "FileView",
    "Timer {",
    "execDetached",
    "notify-send",
    "DBus",
    "import qs.Titonium.Services.Center",
    "CenterAttentionService",
    "CenterActivityService",
)


def public_native_errors(source: str) -> list[str]:
    errors: list[str] = []
    property_pattern = re.compile(
        r"^    (?:(?:readonly|required)\s+)?property\s+[^\n]+$", re.MULTILINE
    )
    for match in property_pattern.finditer(source):
        declaration = match.group(0)
        if re.search(r"\bNotification(?:Server)?\b|:\s*server\b|trackedNotifications|nativeTargets", declaration):
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
    acceptance_path = ROOT / "scripts/notifications_acceptance.sh"
    acceptance = acceptance_path.read_text(encoding="utf-8") if acceptance_path.is_file() else ""
    for fragment in (
        'runtime_dir="$test_dir/data/titonium"',
        'cp -- "$project_root/config/defaults/settings.json" "$runtime_dir/settings.json"',
        'XDG_DATA_HOME="$test_dir/data"',
        'XDG_STATE_HOME="$test_dir/state"',
        'XDG_CACHE_HOME="$test_dir/cache"',
        "org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications",
        '"b true"', '"b false"',
        "snapshot_contract()",
        "policy.get(\"mode\") == \"automatic\"",
        "first_critical_id=",
        "second_critical_id=",
        "first critical fixture was not the FIFO current item",
        "second critical fixture did not advance after first expiry",
        "critical FIFO queue did not drain after final expiry",
        "notifications state", "notifications markRead",
    ):
        if fragment not in acceptance:
            errors.append(f"notifications acceptance missing safe routing coverage: {fragment}")
    if 'qs -p "$project_root" kill' in acceptance:
        errors.append("notifications acceptance must not stop a resident Titonium instance")
    if 'busctl --user status org.freedesktop.Notifications' in acceptance:
        errors.append("notifications acceptance must use NameHasOwner, not an implicit busctl status probe")
    if 'qs -p "$project_root" ipc call app status' in acceptance:
        errors.append("notifications acceptance must not infer notification D-Bus ownership from IPC readiness")
    documents = {
        "README.md": (
            "always-present Notification Bell",
            "independent top-right history panel",
        ),
        "docs/CURRENT_AUDIT.md": (
            "independent Bell-owned history panel",
            "critical FIFO",
        ),
        "docs/ROADMAP.md": (
            "Independent Notification Center — complete",
            "persisted history remains a separately scoped storage decision",
        ),
    }
    forbidden_document_phrases = (
        "direct Notification history route",
        "Notification Center will be rebuilt later",
        "Add Notification Center/actions as a separate Service-contract extension",
    )
    for relative, fragments in documents.items():
        document = (ROOT / relative).read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in document:
                errors.append(f"{relative} missing current notification contract: {fragment}")
        for fragment in forbidden_document_phrases:
            if fragment in document:
                errors.append(f"{relative} retains retired notification contract: {fragment}")


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
    closed = re.search(r"notification\.closed\.connect\(reason => \{(?P<body>.*?)\n\s*\}\);",
                       source, re.DOTALL)
    if not closed:
        errors.append("notification service must handle native close reasons")
    elif "removeLocalNotification" in closed.group("body"):
        errors.append("native close must preserve session history and unread state")
    for destructive in (
        "function removeLocalNotification(",
        "function clearLocalNotifications(",
        "NotificationRules.dismissState",
        "NotificationRules.clearState",
    ):
        if destructive in source:
            errors.append(f"native service retains destructive coordinator ownership: {destructive}")
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
    if "NotificationService" in feature:
        errors.append("notification presentation must consume NotificationCoordinator, not NotificationService")
    for fragment in (
        "import Quickshell.Services.Notifications", "Process", "FileView",
        "execDetached", "MultiEffect", "ShaderEffect", "Animation.Infinite",
        "loops: Animation.Infinite",
    ):
        if fragment in feature:
            errors.append(f"notification presentation has forbidden dependency: {fragment}")
    if feature.count("Timer {") != 1:
        errors.append("notification presentation must own exactly one one-shot toast timer")
    toast_card = (PRESENTATION_ROOT / "ToastCard.qml").read_text(encoding="utf-8")
    dismiss = re.search(r"function\s+dismiss\s*\([^)]*\)[^{]*\{(?P<body>.*?)\n\s*\}",
        toast_card, re.DOTALL)
    if not dismiss:
        errors.append("ToastCard must expose one explicit dismiss path")
    else:
        body = dismiss.group("body")
        stop_index = body.find("toastTimer.stop()")
        dismiss_index = body.find("NotificationCoordinator.dismiss(root.notification.key)")
        if stop_index < 0 or dismiss_index < stop_index:
            errors.append("explicit toast dismiss must stop expiry then synchronously dismiss")
        if "toastExit" in body:
            errors.append("explicit toast dismiss must not depend on an exit animation callback")
    if re.search(r"onFinished\s*:\s*NotificationCoordinator\.dismiss", toast_card):
        errors.append("toast dismissal must not be deferred to an animation completion")
    for locale in ("en", "vi"):
        catalog_path = ROOT / f"config/i18n/{locale}.json"
        catalog = json.loads(catalog_path.read_text(encoding="utf-8")).get("strings", {})
        for key in (
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
    device_path = ROOT / "Titonium/Ipc/DeviceIpc.qml"
    device_source = device_path.read_text(encoding="utf-8") if device_path.is_file() else ""
    if "import qs.Titonium.Core.Runtime" not in device_source:
        errors.append("notifications IPC policy projection must import runtime preferences")
    ipc = notification_ipc(device_source)
    if not ipc:
        errors.append("DeviceIpc must expose the narrow notifications IPC target")
    else:
        methods = set(re.findall(r"^\s*function\s+(\w+)\s*\(", ipc, re.MULTILINE))
        if methods != {"state", "markRead"}:
            errors.append("notifications IPC must expose exactly state and markRead")
        for forbidden in ("dismiss", "action", "inject", "send", "reply"):
            if re.search(rf"\b{forbidden}\w*\s*\(", ipc, re.IGNORECASE):
                errors.append(f"notifications IPC exposes forbidden mutation: {forbidden}")
        for fragment in (
            "NotificationCoordinator.history.length",
            "NotificationCoordinator.toasts.length",
            "NotificationCoordinator.unreadCount",
            "panel: {",
            "open: NotificationCoordinator.panelOpen",
            "ownerId: NotificationCoordinator.coordinatorState.panelOwnerId",
            "queue: {",
            "count: NotificationCoordinator.criticalQueueCount",
            "currentKey: NotificationCoordinator.currentCritical?.key || \"\"",
            "policy: {",
            "mode: Preferences.notifications.policyMode === \"custom\" ? \"custom\" : \"automatic\"",
            "allowCriticalOnIsland: Preferences.notifications.allowCriticalOnIsland !== false",
            "keepCriticalUnread: Preferences.notifications.keepCriticalUnread !== false",
            "NotificationCoordinator.markAllRead()",
        ):
            if fragment not in ipc:
                errors.append(f"notifications IPC missing narrow state contract: {fragment}")
        if "NotificationService" in ipc:
            errors.append("notifications IPC must project NotificationCoordinator state")


def main() -> int:
    errors: list[str] = []
    if not QMLDIR.is_file():
        errors.append("missing Notifications qmldir")
    elif QMLDIR.read_text(encoding="utf-8") != (
        "module Titonium.Services.Notifications\n"
        "singleton NotificationCoordinator 1.0 NotificationCoordinator.qml\n"
        "singleton NotificationService 1.0 NotificationService.qml\n"
    ):
        errors.append("Notifications qmldir must export only its coordinator and native singleton")
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
