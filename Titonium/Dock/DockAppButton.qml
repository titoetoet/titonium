pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Dock
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    required property var dockItem
    property real hoverScale: 1.12
    property int hoverLift: 4
    readonly property int iconSize: 40
    readonly property bool hovered: hoverHandler.hovered
    readonly property int workspaceColorIndex: Number(root.dockItem?.workspaceColorIndex ?? -1)
    readonly property color workspaceBackground: root.workspaceColorIndex >= 0
        ? Theme.workspaceActivePalette[root.workspaceColorIndex % Theme.workspaceActivePalette.length]
        : "transparent"
    signal menuRequested(var dockItem, var invoker)

    function closeTransient(): void {
        if (SurfaceManager.active)
            SurfaceManager.close(SurfaceManager.ownerId);
    }

    function activateOrLaunch(): void {
        root.closeTransient();
        DockService.activateOrLaunch(root.dockItem.appId);
    }

    function launchNew(): void {
        root.closeTransient();
        DockService.launchNew(root.dockItem.appId);
    }

    width: root.iconSize
    height: root.iconSize
    activeFocusOnTab: true
    scale: root.hovered ? root.hoverScale : 1
    y: root.hovered ? -root.hoverLift : 0
    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("dock.application_accessible", {
        "name": root.dockItem?.name || "",
        "count": root.dockItem?.runningCount || 0,
    })
    Accessible.focusable: true

    Behavior on scale {
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        visible: Theme.legacy
        radius: Metrics.radiusMedium
        color: root.dockItem?.active && root.workspaceColorIndex >= 0
            ? root.workspaceBackground
            : (root.hovered || root.activeFocus ? Theme.surfaceInteractive : "transparent")
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: root.activeFocus ? Theme.focus : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }


    Shared.StylePaint {
        anchors.fill: parent
        visible: !Theme.legacy
        tokens: Theme.tokens
        role: "button"
        radius: Metrics.radiusMedium
        customColor: root.dockItem?.active && root.workspaceColorIndex >= 0
            ? root.workspaceBackground : "transparent"
        outlined: false
        interaction: ({ hovered: root.hovered, focused: root.activeFocus,
            selected: root.dockItem?.active === true, quiet: true })
    }

    Shared.SystemIcon {
        anchors.centerIn: parent
        sourceName: root.dockItem?.icon || ""
        fallbackName: "dock_to_bottom"
        size: root.iconSize
        tone: root.dockItem?.urgent ? "warning" : (root.dockItem?.active ? "accent" : "primary")
        accessibleName: ""
    }

    Rectangle {
        width: root.dockItem?.active || root.dockItem?.urgent ? 14 : 6
        height: 3
        radius: height / 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        color: root.dockItem?.urgent ? Theme.warning : Theme.accent
        visible: root.dockItem?.runningCount > 0
    }

    HoverHandler { id: hoverHandler; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: leftTap
        acceptedButtons: Qt.LeftButton
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activateOrLaunch();
        }
    }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.launchNew();
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.menuRequested(root.dockItem, root);
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateOrLaunch();
            event.accepted = true;
        } else if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10
                && (event.modifiers & Qt.ShiftModifier) !== 0)) {
            root.menuRequested(root.dockItem, root);
            event.accepted = true;
        }
    }
}
