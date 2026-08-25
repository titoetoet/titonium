pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

WidgetBase {
    id: root

    readonly property int requestedCount: Number(root.node.props?.count || 5)

    implicitWidth: workspaceRow.implicitWidth + Metrics.spacingXSmall * 2
    implicitHeight: Metrics.widgetHeight

    WorkspacesModel {
        id: workspaceModel
        screen: root.screen
        count: root.requestedCount
    }

    Controls.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusSmall
        outlined: true
    }

    Row {
        id: workspaceRow
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: workspaceModel.count

            Item {
                id: workspaceItem
                required property int index
                readonly property var workspaceState: workspaceModel.items[workspaceItem.index] || ({
                    "id": workspaceItem.index + 1,
                    "active": false,
                    "occupied": false,
                    "urgent": false
                })

                width: Metrics.controlHeightSmall
                height: Metrics.controlHeightSmall - Metrics.spacingXSmall

                Controls.Button {
                    anchors.fill: parent
                    label: String(workspaceItem.workspaceState.id)
                    variant: "quiet"
                    size: "small"
                    selected: workspaceItem.workspaceState.active
                    accessibleName: I18n.tr("menubar.workspace.accessible", {
                        "id": workspaceItem.workspaceState.id,
                        "state": workspaceItem.workspaceState.active
                            ? I18n.tr("menubar.workspace.active")
                            : (workspaceItem.workspaceState.occupied ? I18n.tr("menubar.workspace.occupied") : "")
                    })
                    onTriggered: workspaceModel.activate(workspaceItem.workspaceState.id)
                }

                Rectangle {
                    visible: workspaceItem.workspaceState.occupied && !workspaceItem.workspaceState.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: 3
                    height: 3
                    radius: 2
                    color: workspaceItem.workspaceState.urgent ? Theme.warning : Theme.textSecondary
                }
            }
        }
    }
}
