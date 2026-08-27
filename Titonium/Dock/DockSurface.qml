pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Dock
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property bool revealed: true
    required property var screenModel
    readonly property int bodyHeight: 56
    readonly property int iconSize: 40
    readonly property int itemSpacing: 6
    readonly property real hoverScale: 1.12
    readonly property int hoverLift: 4
    readonly property bool hovered: surfaceHover.hovered
    readonly property bool itemMenuActive: itemMenu.active
    signal applicationsRequested(var screen)

    function closeTransient(): void {
        if (SurfaceManager.active)
            SurfaceManager.close(SurfaceManager.ownerId);
    }

    function openApplications(): void {
        root.closeTransient();
        root.applicationsRequested(root.screenModel);
    }

    implicitWidth: dockRow.implicitWidth + Metrics.spacingSmall * 2
    implicitHeight: root.bodyHeight
    width: implicitWidth
    height: implicitHeight
    opacity: root.revealed ? 1 : 0
    scale: root.revealed ? 1 : 0.98
    activeFocusOnTab: true

    Behavior on opacity {
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusLarge
        color: Theme.surface
        border.width: Metrics.borderWidth
        border.color: Theme.border
    }

    Row {
        id: dockRow
        anchors.centerIn: parent
        spacing: root.itemSpacing

        FocusScope {
            id: applicationsButton
            width: root.iconSize
            height: root.iconSize
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: I18n.tr("dock.applications")
            Accessible.focusable: true

            Rectangle {
                anchors.fill: parent
                radius: Metrics.radiusMedium
                color: applicationsHover.hovered || applicationsButton.activeFocus
                    ? Theme.surfaceInteractive : "transparent"
                border.width: applicationsButton.activeFocus ? Metrics.borderWidth : 0
                border.color: Theme.focus
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            Shared.Icon {
                anchors.centerIn: parent
                name: "rocket_launch"
                size: 28
                tone: "accent"
                accessibleName: ""
            }

            HoverHandler { id: applicationsHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    applicationsButton.forceActiveFocus(Qt.MouseFocusReason);
                    root.openApplications();
                }
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter) {
                    root.openApplications();
                    event.accepted = true;
                }
            }
        }

        Repeater {
            model: DockService.items

            DockAppButton {
                required property var modelData
                dockItem: modelData
                hoverScale: root.hoverScale
                hoverLift: root.hoverLift
                onMenuRequested: (dockItem, invoker) => itemMenu.open(
                    dockItem, invoker, root.screenModel)
            }
        }

    }

    Item {
        id: pinControl
        width: 14
        height: 14
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 4
        anchors.topMargin: 3
        visible: root.hovered
        opacity: pinHover.hovered ? 1 : 0.62
        Accessible.role: Accessible.Button
        Accessible.name: I18n.tr(DockStore.pinnedOpen
            ? "dock.pin_control.close" : "dock.pin_control.open")

        Shared.Icon {
            anchors.centerIn: parent
            name: DockStore.pinnedOpen ? "keep" : "keep_off"
            size: 12
            tone: DockStore.pinnedOpen ? "accent" : "secondary"
            accessibleName: ""
        }

        function togglePinnedOpen(): void {
            DockStore.setPinnedOpen(!DockStore.pinnedOpen);
        }

        HoverHandler { id: pinHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                root.closeTransient();
                pinControl.togglePinnedOpen();
            }
        }
    }

    HoverHandler { id: surfaceHover }

    DockItemMenuCoordinator {
        id: itemMenu
    }
}
