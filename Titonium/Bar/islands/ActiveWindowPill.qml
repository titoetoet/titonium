pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces.Center
import QtQuick.Layouts
import qs.Titonium.Bar.right
import qs.Titonium.Core.Surfaces
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Hyprland
import qs.Titonium.Services.SystemTray
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "ActiveWindowRules.js" as ActiveWindowRules

FocusScope {
    id: root
    required property var screen
    property real menuAnchorOffset: 0
    transform: Translate { x: root.menuAnchorOffset }

    readonly property var activeWindow: HyprlandService.activeWindow
    readonly property string appName: root.activeWindow
        ? ApplicationService.nameForAppId(root.activeWindow.appId) : ""
    readonly property bool trayMenuAvailable: SystemTrayService.hasMenuForApp(
        root.activeWindow?.appId || "", root.appName)
    readonly property string trayContext: SystemTrayService.menuContextForApp(
        root.activeWindow?.appId || "", root.appName)
    readonly property string activityLabel: ActiveWindowRules.label(
        root.appName, root.presentation.title)
    readonly property var presentation: ActiveWindowRules.presentation(
        root.appName,
        root.trayContext,
        root.activeWindow?.title || "",
        root.trayMenuAvailable)
    readonly property bool notchOpen: CenterSurfaceController.ownerScreenName === root.screen.name
    // Centre on the title rail that is actually painted. Using the full layout
    // width is incorrect for long, elided titles (for example Discord), while
    // using titleLabel alone ignores the leading app identity.
    readonly property real menuAnchorX: activityRow.x + activeAppIcon.x
    readonly property real menuAnchorRight: activityRow.x
        + (titleLabel.visible
            ? titleLabel.x + Math.min(titleLabel.width, titleLabel.paintedWidth)
            : appNameLabel.x + Math.min(appNameLabel.width, appNameLabel.paintedWidth))
    readonly property real menuAnchorWidth: Math.max(1,
        root.menuAnchorRight - root.menuAnchorX)

    implicitWidth: Math.min(380, activityRow.implicitWidth + Metrics.spacingLarge * 2)
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Motion.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
    }

    implicitHeight: Metrics.controlHeight
    activeFocusOnTab: true
    Component.onCompleted: root.syncTraySelection()
    onActiveWindowChanged: root.syncTraySelection()
    onAppNameChanged: root.syncTraySelection()



    function syncTraySelection(): void {
        SystemTrayService.selectApp(
            root.activeWindow?.appId || "", root.appName);
    }

    function activate(): void {
        RightPillCoordinator.setInvocationContext(root.screen, root);
        if (RightPillCoordinator.toggleApp(
                root.screen.name, "left", root.activeWindow?.appId || "", root.appName)) {
            CenterSurfaceController.dispatch({ type: "request-mode", mode: "compact" });
            return;
        }
        CenterSurfaceController.dispatch({ type: "request-open",
            screenName: root.screen.name, mode: "expanded" });
    }

    Shared.InteractionFeedback {
        anchors.fill: parent
        anchors.margins: 2
        radius: height / 2
        hovered: centerHover.hovered
        pressed: activeTap.pressed
        selected: (root.notchOpen && CenterSurfaceController.active)
            || (RightPillCoordinator.menuActive && RightPillCoordinator.activeEdge === "left"
                && RightPillCoordinator.ownerScreenName === root.screen.name)
            || SurfaceManager.ownerId === RightPillCoordinator.systemTrayOwnerFor(root.screen, "app")
        focused: root.activeFocus
    }

    RowLayout {
        id: activityRow
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacingLarge
        anchors.rightMargin: Metrics.spacingLarge
        spacing: Metrics.spacingSmall

        Shared.SystemIcon {
            id: activeAppIcon
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            sourceName: root.activeWindow?.icon || ""
            fallbackName: "deployed_code"
            size: 20
            tone: root.notchOpen ? "accent" : "secondary"
        }

        Shared.TextLabel {
            id: appNameLabel
            Layout.maximumWidth: 120
            text: root.presentation.appName
            variant: "label"
            strong: true
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Shared.TextLabel {
            id: activityDot
            text: "·"
            visible: root.presentation.hasContext
            variant: "label"
            tone: "secondary"
        }

        Shared.TextLabel {
            id: titleLabel
            Layout.minimumWidth: 0
            Layout.fillWidth: true
            Layout.maximumWidth: 220
            visible: root.presentation.hasContext
            text: root.presentation.title
            variant: "label"
            strong: false
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    HoverHandler {
        id: centerHover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: activeTap
        onTapped: root.activate()
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("menubar.center_notch.accessible")
    Accessible.focusable: true
}
