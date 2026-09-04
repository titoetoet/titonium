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
    edge_surface = read("Titonium/Bar/right/EdgeMenuSurface.qml", errors)
    edge_window = read("Titonium/Bar/right/EdgeMenuWindow.qml", errors)
    classic_bar = read("Titonium/Bar/classic/ClassicBar.qml", errors)
    classic_end = read("Titonium/Bar/classic/ClassicEndIsland.qml", errors)
    router = read("Titonium/Orchestration/SurfaceRouter.qml", errors)
    coordinator = read("Titonium/Services/Notifications/NotificationCoordinator.qml", errors)
    overlay_host = read("Titonium/Core/Surfaces/OverlayHost.qml", errors)
    panel = read("Titonium/Notifications/NotificationPanel.qml", errors)
    classic_panel = read("Titonium/Notifications/ClassicNotificationPanel.qml", errors)
    connected_panel = read(
        "Titonium/Notifications/ConnectedNotificationPanelContent.qml", errors)
    content = read("Titonium/Notifications/NotificationHistoryContent.qml", errors)
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
    require(edge_surface, "EdgeMenuSurface active-input notification route", (
        "signal notificationsRequested(var screen, var invoker)",
        "onNotificationsRequested: (screen, invoker) =>",
        "root.notificationsRequested(screen, invoker)",
    ), errors)
    require(edge_window, "EdgeMenuWindow active-input notification route", (
        "signal notificationsRequested(var screen, var invoker)",
        "onNotificationsRequested: (screen, invoker) =>",
        "window.notificationsRequested(screen, invoker)",
    ), errors)
    if not re.search(
            r"EdgeMenuWindow\s*\{[\s\S]*?onNotificationsRequested:\s*"
            r"\(screen, invoker\)\s*=>\s*root\.notificationsRequested\(screen, invoker\)",
            bar_host):
        errors.append(
            "BarHost must forward notification requests from the input-owning EdgeMenuWindow")
    require(edge_surface, "EdgeMenuSurface connected release guards", (
        "RightPillCoordinator.releaseConnectedSurface(loadOwnerId, loadGeneration,",
        "loadDescriptor, loadScreen)",
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
        "NotificationPanelRouting.presentation(RightPillCoordinator.presentedStyle)",
        "BarPopupRouting.existingOpenAction(owner,",
        "RightPillCoordinator.toggleConnectedSurface(owner)",
        "SurfaceManager.close(owner)",
        'Qt.resolvedUrl("../Notifications/" + route.source)',
        '"keyboardFocus": "exclusive"',
        '"closeOnMonitorChange": true',
        '"feature": "notifications"',
        '"barConnected": route.owner === "edge"',
        '"anchor": route.anchor',
        '"invoker": invoker',
        "SettingsLifecycleRules.canYield(SettingsCoordinator.active, Preferences.savePending)",
        'root.closeCenter("notifications-opened")',
        "RightPillCoordinator.close()",
        "SurfaceManager.open(owner,",
    ), errors)
    toggle = function_block(router, "toggleNotificationPanel")
    if "NotificationCoordinator.markAllRead()" in toggle:
        errors.append("SurfaceRouter must not mark history read before the lazy panel mounts")
    require(connected_end, "EndIsland notification anchor", (
        "function anchorRect(name: string): rect",
        'name === "notifications"',
        "notifications.mapToItem(root, 0, 0)",
        "id: notifications",
    ), errors)
    require(edge_surface, "EdgeMenuSurface notification anchor", (
        "rightContent.anchorRect(",
        "RightPillCoordinator.connectedDescriptor?.anchor",
    ), errors)

    require(coordinator, "NotificationCoordinator", (
        "readonly property bool panelOpen: root.coordinatorState.panelOpen",
        "function panelMounted(ownerId: string): bool",
        "CoordinatorRules.mountPanel(root.coordinatorState, ownerId)",
        "function panelUnmounted(ownerId: string): bool",
        "CoordinatorRules.unmountPanel(root.coordinatorState, ownerId)",
    ), errors)

    require(classic_panel, "ClassicNotificationPanel", (
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
        "NotificationHistoryContent {", "onDismissRequested: root.close()",
        "Qt.Key_Escape",
        "Component.onCompleted:",
        "root.syncPanelMount()",
        "Component.onDestruction:",
        "root.teardownPanelMount()",
    ), errors)
    completed = re.search(r"Component\.onCompleted\s*:\s*\{(?P<body>.*?)\n\s*\}",
        classic_panel, re.DOTALL)
    if not completed or "root.syncPanelMount()" not in completed.group("body"):
        errors.append("ClassicNotificationPanel must defer mount until its descriptor owner is assigned")
    elif "NotificationCoordinator.panelMounted" in completed.group("body") \
            or "NotificationCoordinator.markAllRead" in completed.group("body"):
        errors.append("ClassicNotificationPanel completion must not mark an empty pre-assignment owner")
    sync_mount = function_block(classic_panel, "syncPanelMount")
    for fragment in ("NotificationCoordinator.panelUnmounted(plan.unmountOwnerId)",
            "NotificationCoordinator.panelMounted(plan.mountOwnerId)",
            "NotificationCoordinator.markAllRead()"):
        if fragment not in sync_mount:
            errors.append(f"ClassicNotificationPanel late-mount path missing: {fragment}")
    teardown_mount = function_block(classic_panel, "teardownPanelMount")
    if "NotificationCoordinator.panelUnmounted(plan.unmountOwnerId)" not in teardown_mount:
        errors.append("ClassicNotificationPanel teardown must unmount its cached owner")
    require(connected_panel, "ConnectedNotificationPanelContent", (
        "Item {", "property real availableViewportHeight:",
        "signal dismissRequested()",
        'import "NotificationPanelLifecycle.js" as NotificationPanelLifecycle',
        "property bool loaded: false",
        'property string mountedOwnerId: ""',
        "RightPillCoordinator.connectedDescriptor?.feature === \"notifications\"",
        "RightPillCoordinator.connectedOwnerId",
        "function syncPanelMount(): void",
        "if (!root.loaded)",
        "NotificationPanelLifecycle.transition(",
        "function teardownPanelMount(): void",
        "NotificationPanelLifecycle.teardown(root.mountedOwnerId)",
        "NotificationCoordinator.panelMounted(plan.mountOwnerId)",
        "NotificationCoordinator.panelUnmounted(plan.unmountOwnerId)",
        "NotificationCoordinator.markAllRead()",
        "NotificationHistoryContent {",
        "onDismissRequested: root.dismissRequested()",
        "onOwnerIdChanged: root.syncPanelMount()",
        "root.loaded = true",
        "root.syncPanelMount()",
        "Component.onDestruction: root.teardownPanelMount()",
    ), errors)
    for forbidden in ("SurfaceManager", "PanelWindow", "Shared.Panel",
            "forceActiveFocus", "property var descriptor", "property var screen"):
        if forbidden in connected_panel:
            errors.append(
                f"ConnectedNotificationPanelContent must leave chassis ownership to EdgeMenuSurface: {forbidden}")
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
    require(content, "NotificationHistoryContent", (
        "readonly property real implicitContentWidth:",
        "readonly property real implicitContentHeight:",
        "signal dismissRequested()",
        "model: NotificationCoordinator.history", "NotificationHistoryRow {",
        "visible: NotificationCoordinator.history.length === 0",
        'I18n.tr("notification.panel.empty")',
        'I18n.tr("notification.panel.title")',
        'I18n.tr("notification.panel.clear_all")',
        "NotificationCoordinator.dismissAll()", "root.dismissRequested()",
    ), errors)
    for forbidden in ("SurfaceManager", "PanelWindow", "property var descriptor",
            "property var screen", "NotificationService"):
        if forbidden in content:
            errors.append(f"NotificationHistoryContent must not own shell or native API: {forbidden}")
    require(panel, "NotificationPanel compatibility wrapper", (
        "ClassicNotificationPanel {",
    ), errors)
    for forbidden in ("NotificationPanelLifecycle", "SurfaceManager", "NotificationCoordinator",
            "property var descriptor", "property var screen"):
        if forbidden in panel:
            errors.append(f"NotificationPanel compatibility wrapper must delegate lifecycle: {forbidden}")
    presentation = content + row
    if "NotificationService" in presentation:
        errors.append("Notification panel presentation must not consume NotificationService")
    require(qmldir, "Notifications qmldir", (
        "NotificationPanel 1.0 NotificationPanel.qml",
        "ClassicNotificationPanel 1.0 ClassicNotificationPanel.qml",
        "NotificationHistoryContent 1.0 NotificationHistoryContent.qml",
        "ConnectedNotificationPanelContent 1.0 ConnectedNotificationPanelContent.qml",
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
