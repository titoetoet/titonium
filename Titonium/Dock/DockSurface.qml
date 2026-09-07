pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Dock
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    readonly property bool connected: Preferences.dockStyle === "connected"
    property bool revealed: true
    required property var screenModel
    readonly property int bodyHeight: 56
    readonly property int iconSize: 40
    readonly property int itemSpacing: 6
    readonly property real hoverScale: 1.12
    readonly property int hoverLift: 4
    readonly property bool hovered: surfaceHover.hovered
    readonly property bool itemMenuActive: itemMenu.active
    readonly property alias pinHitbox: pinControl
    signal applicationsRequested(var screen)

    function closeTransient(): void {
        if (SurfaceManager.active)
            SurfaceManager.close(SurfaceManager.ownerId);
    }

    function openApplications(): void {
        root.closeTransient();
        root.applicationsRequested(root.screenModel);
    }

    implicitWidth: dockRow.implicitWidth + 48
    implicitHeight: 64
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
        id: dockPanel
        x: 12
        y: root.connected ? 8 : 0
        width: dockRow.implicitWidth + 24
        height: root.bodyHeight
        radius: Metrics.radiusLarge
        visible: !root.connected && Theme.legacy
        color: Theme.surfaceElevated
        border.width: Metrics.borderWidth
        border.color: Theme.border

    }

    Shared.StylePaint {
        x: dockPanel.x
        y: dockPanel.y
        width: dockPanel.width
        height: dockPanel.height
        visible: !root.connected && !Theme.legacy
        tokens: Theme.tokens
        role: "panel"
        radius: Metrics.radiusLarge
    }

    Shared.ConnectedPillShape {
        x: dockPanel.x - shoulderSize
        y: dockPanel.y
        bodyWidth: dockPanel.width
        bodyHeight: root.bodyHeight
        shoulderSize: 12
        bottomRadius: 20
        rotation: 180
        visible: root.connected
        color: Theme.connectedSurface
    }

    Row {
        id: dockRow
        anchors.centerIn: dockPanel
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
                visible: Theme.legacy
                color: applicationsHover.hovered || applicationsButton.activeFocus
                    ? Theme.surfaceInteractive : "transparent"
                border.width: applicationsButton.activeFocus ? Metrics.borderWidth : 0
                border.color: Theme.focus
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            Shared.StylePaint {
                anchors.fill: parent
                visible: !Theme.legacy
                tokens: Theme.tokens
                role: "button"
                radius: Metrics.radiusMedium
                interaction: ({ hovered: applicationsHover.hovered,
                    focused: applicationsButton.activeFocus, quiet: true })
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
        x: dockPanel.x - width / 2
        y: dockPanel.y + (dockPanel.height - height) / 2
        width: 22
        height: 22
        z: 10
        opacity: root.hovered || pinHover.hovered ? 1 : 0
        Accessible.role: Accessible.Button
        Accessible.name: I18n.tr(DockStore.pinnedOpen
            ? "dock.pin_control.close" : "dock.pin_control.open")

        Behavior on opacity {
            NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: Theme.legacy
            color: pinHover.hovered ? Theme.surfaceInteractive : Theme.surfaceElevated
            border.width: Metrics.borderWidth
            border.color: DockStore.pinnedOpen ? Theme.accent : Theme.border
        }


        Shared.StylePaint {
            anchors.fill: parent
            visible: !Theme.legacy
            tokens: Theme.tokens
            role: "button"
            radius: width / 2
            borderColor: DockStore.pinnedOpen ? Theme.accent : Theme.border
            interaction: ({ hovered: pinHover.hovered, selected: DockStore.pinnedOpen,
                quiet: true })
        }

        Shared.Icon {
            anchors.centerIn: parent
            name: DockStore.pinnedOpen ? "keep" : "keep_off"
            size: 12
            tone: DockStore.pinnedOpen ? "accent" : "secondary"
            accessibleName: ""
        }

        function togglePinnedOpen(): void {
            const result = DockStore.setPinnedOpen(!DockStore.pinnedOpen);
            if (!result.accepted)
                Logger.warn("dock", "visibility pin mutation rejected: " + result.error);
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
