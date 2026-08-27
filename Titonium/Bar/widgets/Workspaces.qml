pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Hyprland
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root

    required property var screen
    property int count: 5
    readonly property int emptySlotWidth: 24
    readonly property int appIconSize: 17
    readonly property int appSpacing: 3
    readonly property int activeWorkspaceId: HyprlandService.activeWorkspaceId(root.screen)
    readonly property var items: HyprlandService.workspaceSnapshot(root.screen, root.count)

    implicitWidth: workspaceRow.implicitWidth + Metrics.spacingSmall * 2
    implicitHeight: Metrics.widgetHeight

    function activateRelative(delta: int): void {
        const id = Math.max(1, root.activeWorkspaceId + delta);
        HyprlandService.activateWorkspace(id);
    }

    function workspaceColor(index: int, active: bool): color {
        const palette = active ? Theme.workspaceActivePalette : Theme.workspacePalette;
        return palette[Math.max(0, index) % palette.length];
    }

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: Metrics.spacingSmall

        Repeater {
            model: root.items

            Item {
                id: workspaceItem
                required property var modelData
                readonly property int occupiedWidth: Math.max(36,
                    workspaceItem.modelData.apps.length * root.appIconSize
                        + Math.max(0, workspaceItem.modelData.apps.length - 1) * root.appSpacing
                        + Metrics.spacingMedium)
                width: workspaceItem.modelData.occupied
                    ? workspaceItem.occupiedWidth : root.emptySlotWidth
                height: 26
                Accessible.role: Accessible.Button
                Accessible.name: I18n.tr("menubar.workspace.accessible", {
                    id: workspaceItem.modelData.id,
                    state: workspaceItem.modelData.active
                        ? I18n.tr("menubar.workspace.active")
                        : (workspaceItem.modelData.occupied
                            ? I18n.tr("menubar.workspace.occupied") : "")
                })

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: workspaceItem.modelData.occupied
                    height: workspaceItem.modelData.active ? 26 : 20
                    radius: Metrics.radiusLarge
                    color: root.workspaceColor(workspaceItem.modelData.colorIndex,
                        workspaceItem.modelData.active)
                    opacity: workspaceItem.modelData.active ? 1.0 : 0.62
                    border.width: workspaceItem.modelData.urgent ? Metrics.borderWidth : 0
                    border.color: workspaceItem.modelData.urgent ? Theme.warning : "transparent"

                    Behavior on height {
                        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !workspaceItem.modelData.occupied
                    width: workspaceItem.modelData.active ? 10 : 7
                    height: width
                    radius: width / 2
                    color: workspaceItem.modelData.active ? Theme.accent : Theme.textSecondary
                    border.width: workspaceItem.modelData.urgent ? Metrics.borderWidth : 0
                    border.color: Theme.warning
                }

                Row {
                    anchors.centerIn: parent
                    spacing: root.appSpacing
                    visible: workspaceItem.modelData.occupied

                    Repeater {
                        model: workspaceItem.modelData.apps

                        Shared.SystemIcon {
                            required property var modelData
                            sourceName: modelData.icon
                            fallbackName: "apps"
                            size: root.appIconSize
                            tone: "primary"
                            accessibleName: ""
                        }
                    }
                }

                Behavior on width {
                    NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: HyprlandService.activateWorkspace(workspaceItem.modelData.id)
                }
            }
        }
    }

    WheelHandler {
        target: null
        onWheel: event => {
            if (event.angleDelta.y === 0)
                return;
            root.activateRelative(event.angleDelta.y > 0 ? -1 : 1);
            event.accepted = true;
        }
    }
}
