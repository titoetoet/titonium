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
    readonly property int activeWorkspaceId: HyprlandService.activeWorkspaceId(root.screen)
    readonly property var items: HyprlandService.workspaceSnapshot(root.screen, root.count)

    implicitWidth: workspaceRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight

    Shared.Surface { anchors.fill: parent; tone: "elevated"; radius: Metrics.radiusSmall }

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        Repeater {
            model: root.count
            Item {
                id: workspaceItem
                required property int index
                readonly property var workspaceState: root.items[index] || ({ id: index + 1,
                    active: false, occupied: false, urgent: false })
                width: Metrics.controlHeightSmall
                height: Metrics.controlHeightSmall - Metrics.spacingXSmall
                Shared.Button {
                    anchors.fill: parent
                    label: String(workspaceItem.workspaceState.id)
                    variant: "quiet"
                    size: "small"
                    selected: workspaceItem.workspaceState.active
                    accessibleName: I18n.tr("menubar.workspace.accessible", {
                        id: workspaceItem.workspaceState.id,
                        state: workspaceItem.workspaceState.active ? I18n.tr("menubar.workspace.active")
                            : (workspaceItem.workspaceState.occupied
                                ? I18n.tr("menubar.workspace.occupied") : "")
                    })
                    onTriggered: HyprlandService.activateWorkspace(workspaceItem.workspaceState.id)
                }
                Rectangle {
                    visible: workspaceItem.workspaceState.occupied && !workspaceItem.workspaceState.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: 3; height: 3; radius: 2
                    color: workspaceItem.workspaceState.urgent ? Theme.warning : Theme.textSecondary
                }
            }
        }
    }
}
