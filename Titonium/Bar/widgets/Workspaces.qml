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
    readonly property int emptySlotWidth: 20
    readonly property int appIconSize: 14
    readonly property int appSpacing: 2
    readonly property int activeWorkspaceId: HyprlandService.activeWorkspaceId(root.screen)
    readonly property var items: HyprlandService.workspaceSnapshot(root.screen, root.count)

    implicitWidth: workspaceRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight

    function activateRelative(delta: int): void {
        const id = Math.max(1, root.activeWorkspaceId + delta);
        HyprlandService.activateWorkspace(id);
    }

    function workspaceColor(index: int): color {
        const palette = Theme.workspacePalette;
        return palette[Math.max(0, index) % palette.length];
    }

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: Metrics.spacingXSmall

        Repeater {
            model: root.items

            Item {
                id: workspaceItem
                required property var modelData
                readonly property int occupiedWidth: Math.max(28,
                    workspaceItem.modelData.apps.length * root.appIconSize
                        + Math.max(0, workspaceItem.modelData.apps.length - 1) * root.appSpacing
                        + Metrics.spacingSmall)
                width: workspaceItem.modelData.occupied
                    ? workspaceItem.occupiedWidth : root.emptySlotWidth
                height: 22
                Accessible.role: Accessible.Button
                Accessible.name: I18n.tr("menubar.workspace.accessible", {
                    id: workspaceItem.modelData.id,
                    state: workspaceItem.modelData.active
                        ? I18n.tr("menubar.workspace.active")
                        : (workspaceItem.modelData.occupied
                            ? I18n.tr("menubar.workspace.occupied") : "")
                })

                Rectangle {
                    anchors.fill: parent
                    visible: workspaceItem.modelData.occupied
                    radius: Metrics.radiusLarge
                    color: root.workspaceColor(workspaceItem.modelData.colorIndex)
                    border.width: workspaceItem.modelData.active ? Metrics.borderWidth : 0
                    border.color: workspaceItem.modelData.urgent ? Theme.warning
                        : (workspaceItem.modelData.active ? Theme.focus : "transparent")
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !workspaceItem.modelData.occupied
                    width: workspaceItem.modelData.active ? 8 : 6
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
