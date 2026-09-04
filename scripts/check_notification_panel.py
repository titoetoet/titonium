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


def obsolete_bell_copy_consumers(errors: list[str]) -> None:
    for path in (ROOT / "Titonium").rglob("*"):
        if path.suffix not in (".js", ".qml"):
            continue
        if "notification.bell." in path.read_text(encoding="utf-8"):
            errors.append(
                f"production consumer retains removed bell copy: {path.relative_to(ROOT)}")


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
    overlay_host = read("Titonium/Core/Surfaces/OverlayHost.qml", errors)
    panel = read("Titonium/Notifications/NotificationPanel.qml", errors)
    lifecycle = read("Titonium/Notifications/NotificationPanelLifecycle.js", errors)
    row = read("Titonium/Notifications/NotificationHistoryRow.qml", errors)
    qmldir = read("Titonium/Notifications/qmldir", errors)
    app = read("Titonium/App.qml", errors)

    require(bell, "NotificationBell", (
        "required property var screen",
        "signal toggleRequested(var screen, var invoker)",
        'readonly property string iconName: "history"',
        "name: root.iconName",
        "NotificationCoordinator.unreadCount",
        "NotificationCoordinator.hasUnread",
        "visible: NotificationCoordinator.hasUnread",
        "root.toggleRequested(root.screen, root)",
        'I18n.tr(NotificationCoordinator.hasUnread',
        '"notification.center.none"',
        '"notification.center.unread"',
        "function activate(): void",
        "Accessible.focusable: true",
        "Accessible.onPressAction: root.activate()",
    ), errors)
    if re.search(r"^    visible:\s*NotificationCoordinator\.hasUnread\s*$", bell, re.MULTILINE):
        errors.append("NotificationBell itself must always render; only its badge may be conditional")
    if "NotificationService" in bell or "CenterSurfaceController" in bell:
        errors.append("NotificationBell must request routing and consume only NotificationCoordinator")
    if "activeFocusOnTab: true" in bell or "Keys.onPressed:" in bell:
        errors.append("passive Bar bell must not advertise an unreachable keyboard-focus route")
    if "SequentialAnimation" in bell or 'property: "rotation"' in bell:
        errors.append("Topbar Notification Center must not own bell motion")
    if connected_end.rfind("NotificationBell {") < connected_end.rfind("ConnectivityPill {"):
        errors.append("Connected Notification Center must be the rightmost control")
    if classic_end.rfind("NotificationBell {") < classic_end.rfind("StatusPill {"):
        errors.append("Classic Notification Center must be the rightmost surface")

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
        "GlobalShortcut {",
        'appid: "titonium"',
        'name: "notifications"',
        'description: I18n.tr("shortcut.notifications.description")',
        "onPressed: router.toggleNotificationPanel(null, null)",
    ), errors)
    if app.count('name: "notifications"') != 1:
        errors.append("App must register exactly one notification panel global shortcut")

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
        'import "NotificationPanelLifecycle.js" as NotificationPanelLifecycle',
        'property string mountedOwnerId: ""',
        "function syncPanelMount(): void",
        "NotificationPanelLifecycle.transition(",
        "function teardownPanelMount(): void",
        "NotificationPanelLifecycle.teardown(root.mountedOwnerId)",
        "onOwnerIdChanged: root.syncPanelMount()",
        "SurfaceManager.beginClose", "SurfaceManager.closeOwned",
        "Metrics.barHeight + Metrics.barSpacing", "anchors.right: parent.right",
        "model: NotificationCoordinator.history", "NotificationHistoryRow {",
        "visible: NotificationCoordinator.history.length === 0",
        'I18n.tr("notification.panel.empty")',
        'I18n.tr("notification.panel.title")',
        'I18n.tr("notification.panel.clear_all")',
        "NotificationCoordinator.dismissAll()", "Qt.Key_Escape",
        "Component.onCompleted:",
        "root.syncPanelMount()",
        "Component.onDestruction:",
        "root.teardownPanelMount()",
    ), errors)
    completed = re.search(r"Component\.onCompleted\s*:\s*\{(?P<body>.*?)\n\s*\}",
        panel, re.DOTALL)
    if not completed or "root.syncPanelMount()" not in completed.group("body"):
        errors.append("NotificationPanel must defer mount until its descriptor owner is assigned")
    elif "NotificationCoordinator.panelMounted" in completed.group("body") \
            or "NotificationCoordinator.markAllRead" in completed.group("body"):
        errors.append("NotificationPanel completion must not mark an empty pre-assignment owner")
    sync_mount = function_block(panel, "syncPanelMount")
    for fragment in ("NotificationCoordinator.panelUnmounted(plan.unmountOwnerId)",
            "NotificationCoordinator.panelMounted(plan.mountOwnerId)",
            "NotificationCoordinator.markAllRead()"):
        if fragment not in sync_mount:
            errors.append(f"NotificationPanel late-mount path missing: {fragment}")
    teardown_mount = function_block(panel, "teardownPanelMount")
    if "NotificationCoordinator.panelUnmounted(plan.unmountOwnerId)" not in teardown_mount:
        errors.append("NotificationPanel teardown must unmount its cached owner")
    error_handler = re.search(r"else if \(status === Loader\.Error\)(?P<body>[^}]*)",
        overlay_host, re.DOTALL)
    if not error_handler or "releaseSnapshot()" not in error_handler.group("body"):
        errors.append("OverlayHost Loader.Error must only release its captured surface")
    elif "NotificationCoordinator" in error_handler.group("body"):
        errors.append("OverlayHost Loader.Error must never mark notification state")
    require(lifecycle, "NotificationPanelLifecycle", (
        "function transition(currentOwnerId, requestedOwnerId)",
        "function teardown(currentOwnerId)",
    ), errors)
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
        "notification.center.none", "notification.center.unread",
        "notification.panel.title", "notification.panel.empty",
        "notification.panel.clear_all", "notification.panel.dismiss",
        "shortcut.notifications.description",
    )
    for locale in ("en", "vi"):
        catalog = json.loads((ROOT / f"config/i18n/{locale}.json").read_text(
            encoding="utf-8")).get("strings", {})
        for key in keys:
            if not isinstance(catalog.get(key), str) or not catalog[key]:
                errors.append(f"{locale} catalog missing Notification panel key: {key}")

    obsolete_bell_copy_consumers(errors)

    if errors:
        print("FAIL notification panel, bell and route contract")
        print("\n".join(errors))
        return 1
    print("PASS lazy notification panel, bell ownership and route contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
