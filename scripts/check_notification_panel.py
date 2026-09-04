#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str, errors: list[str]) -> str:
    path = ROOT / relative
    if not path.is_file():
        errors.append(f"missing notification panel contract: {relative}")
        return ""
    return path.read_text(encoding="utf-8")


def require(source: str, label: str, fragments: tuple[str, ...], errors: list[str]) -> None:
    for fragment in fragments:
        if fragment not in source:
            errors.append(f"{label} missing contract: {fragment}")


def function_block(source: str, name: str) -> str:
    match = re.search(rf"\bfunction\s+{re.escape(name)}\s*\([^)]*\)[^{{]*{{", source)
    if not match:
        return ""
    opening = source.find("{", match.start())
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[match.start():index + 1]
    return ""


def main() -> int:
    errors: list[str] = []
    bell = read("Titonium/Bar/widgets/NotificationBell.qml", errors)
    bar_host = read("Titonium/Bar/BarHost.qml", errors)
    bar_surface = read("Titonium/Bar/BarSurface.qml", errors)
    connected_bar = read("Titonium/Bar/Bar.qml", errors)
    connected_end = read("Titonium/Bar/islands/EndIsland.qml", errors)
    classic_bar = read("Titonium/Bar/classic/ClassicBar.qml", errors)
    classic_end = read("Titonium/Bar/classic/ClassicEndIsland.qml", errors)
    router = read("Titonium/Orchestration/SurfaceRouter.qml", errors)
    coordinator = read("Titonium/Services/Notifications/NotificationCoordinator.qml", errors)
    panel = read("Titonium/Notifications/NotificationPanel.qml", errors)
    row = read("Titonium/Notifications/NotificationHistoryRow.qml", errors)
    qmldir = read("Titonium/Notifications/qmldir", errors)
    app = read("Titonium/App.qml", errors)

    require(bell, "NotificationBell", (
        "required property var screen",
        "signal toggleRequested(var screen, var invoker)",
        "NotificationCoordinator.unreadCount",
        "NotificationCoordinator.hasUnread",
        "visible: NotificationCoordinator.hasUnread",
        "root.toggleRequested(root.screen, root)",
        'I18n.tr(NotificationCoordinator.hasUnread',
        '"notification.bell.none"',
        '"notification.bell.unread"',
        "activeFocusOnTab: true",
        "function activate(): void",
        "root.forceActiveFocus(Qt.MouseFocusReason)",
        "Keys.onPressed:",
        "Qt.Key_Space", "Qt.Key_Return", "Qt.Key_Enter",
        "Accessible.focusable: true",
        "Accessible.onPressAction: root.activate()",
        "root.activeFocus ? Theme.focus",
    ), errors)
    if re.search(r"^    visible:\s*NotificationCoordinator\.hasUnread\s*$", bell, re.MULTILINE):
        errors.append("NotificationBell itself must always render; only its badge may be conditional")
    if "NotificationService" in bell or "CenterSurfaceController" in bell:
        errors.append("NotificationBell must request routing and consume only NotificationCoordinator")

    for source, label in ((connected_end, "EndIsland"),
            (classic_end, "ClassicEndIsland")):
        require(source, label, (
            "signal notificationsRequested(var screen, var invoker)",
            "onToggleRequested:",
        ), errors)
    propagation = (
        (connected_bar, "Bar"), (classic_bar, "ClassicBar"),
        (bar_surface, "BarSurface"), (bar_host, "BarHost"),
    )
    for source, label in propagation:
        require(source, label, (
            "signal notificationsRequested(var screen, var invoker)",
            "onNotificationsRequested:",
        ), errors)
    require(classic_end, "ClassicEndIsland", (
        "NotificationBell {", "readonly property alias notificationHitbox:",
    ), errors)
    require(classic_bar, "ClassicBar", (
        "readonly property alias notificationHitbox:",
    ), errors)
    require(bar_surface, "BarSurface", (
        "readonly property var classicNotificationHitbox:",
        "Region { item: root.classicNotificationHitbox }",
    ), errors)
    require(app, "App", (
        "onNotificationsRequested: (screen, invoker) =>",
        "router.toggleNotificationPanel(screen, invoker)",
    ), errors)

    require(router, "SurfaceRouter", (
        "function toggleNotificationPanel(requestedScreen: var, invoker: var): string",
        "NotificationPanelRouting.ownerId(screen.name)",
        "NotificationPanelRouting.toggleAction(SurfaceManager.ownerId, owner)",
        'Qt.resolvedUrl("../Notifications/NotificationPanel.qml")',
        '"keyboardFocus": "exclusive"',
        '"closeOnMonitorChange": true',
        "SettingsLifecycleRules.canYield(SettingsCoordinator.active, Preferences.savePending)",
        'root.closeCenter("notifications-opened")',
        "RightPillCoordinator.close()",
        "SurfaceManager.open(owner,",
    ), errors)
    toggle = function_block(router, "toggleNotificationPanel")
    if "NotificationCoordinator.markAllRead()" in toggle:
        errors.append("SurfaceRouter must not mark history read before the lazy panel mounts")

    require(coordinator, "NotificationCoordinator", (
        "readonly property bool panelOpen: root.coordinatorState.panelOpen",
        "function panelMounted(ownerId: string): bool",
        "CoordinatorRules.mountPanel(root.coordinatorState, ownerId)",
        "function panelUnmounted(ownerId: string): bool",
        "CoordinatorRules.unmountPanel(root.coordinatorState, ownerId)",
    ), errors)

    require(panel, "NotificationPanel", (
        "FocusScope {", "property var descriptor:", "property var screen:",
        "SurfaceManager.beginClose", "SurfaceManager.closeOwned",
        "Metrics.barHeight + Metrics.barSpacing", "anchors.right: parent.right",
        "model: NotificationCoordinator.history", "NotificationHistoryRow {",
        "visible: NotificationCoordinator.history.length === 0",
        'I18n.tr("notification.panel.empty")',
        'I18n.tr("notification.panel.title")',
        'I18n.tr("notification.panel.clear_all")',
        "NotificationCoordinator.dismissAll()", "Qt.Key_Escape",
        "Component.onCompleted:",
        "NotificationCoordinator.panelMounted(root.ownerId)",
        "NotificationCoordinator.markAllRead()",
        "Component.onDestruction:",
        "NotificationCoordinator.panelUnmounted(root.ownerId)",
    ), errors)
    completed = re.search(r"Component\.onCompleted\s*:\s*\{(?P<body>.*?)\n\s*\}",
        panel, re.DOTALL)
    if not completed or "NotificationCoordinator.panelMounted(root.ownerId)" not in completed.group("body") \
            or "NotificationCoordinator.markAllRead()" not in completed.group("body"):
        errors.append("NotificationPanel must mark read only from its successful mount boundary")
    require(row, "NotificationHistoryRow", (
        "required property var notification", "Shared.SystemIcon",
        "model: root.notification.actions", "NotificationCoordinator.action(",
        "NotificationCoordinator.dismiss(root.notification.key)",
        'I18n.tr("notification.panel.dismiss")',
    ), errors)
    presentation = panel + row
    if "NotificationService" in presentation:
        errors.append("Notification panel presentation must not consume NotificationService")
    require(qmldir, "Notifications qmldir", (
        "NotificationPanel 1.0 NotificationPanel.qml",
        "NotificationHistoryRow 1.0 NotificationHistoryRow.qml",
    ), errors)
    if "NotificationPanel {" in app:
        errors.append("App must not eagerly compose NotificationPanel; SurfaceManager loads it lazily")

    keys = (
        "notification.panel.title", "notification.panel.empty",
        "notification.panel.clear_all", "notification.panel.dismiss",
    )
    for locale in ("en", "vi"):
        catalog = json.loads((ROOT / f"config/i18n/{locale}.json").read_text(
            encoding="utf-8")).get("strings", {})
        for key in keys:
            if not isinstance(catalog.get(key), str) or not catalog[key]:
                errors.append(f"{locale} catalog missing Notification panel key: {key}")

    if errors:
        print("FAIL notification panel, bell and route contract")
        print("\n".join(errors))
        return 1
    print("PASS lazy notification panel, bell ownership and route contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
