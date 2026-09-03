pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.islands
import qs.Titonium.Bar.widgets
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    implicitWidth: startRow.implicitWidth
    implicitHeight: Metrics.widgetHeight

    Row {
        id: startRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Metrics.spacingSmall

        Item {
            id: archSurface
            width: archLogo.width + Metrics.spacingXSmall * 2
            height: Metrics.widgetHeight

            Shared.Surface {
                anchors.fill: parent
                tone: "elevated"
                radius: Metrics.radiusLarge
            }

            ArchLogo {
                id: archLogo
                anchors.centerIn: parent
            }
        }

        Item {
            id: workspaceSurface
            width: workspaces.implicitWidth + Metrics.spacingXSmall * 2
            height: Metrics.widgetHeight

            Shared.Surface {
                anchors.fill: parent
                tone: "elevated"
                radius: Metrics.radiusLarge
            }

            Workspaces {
                id: workspaces
                anchors.centerIn: parent
                screen: root.screen
            }
        }

        Item {
            id: activeWindowSurface
            width: activeWindow.implicitWidth
            height: Metrics.widgetHeight

            Shared.Surface {
                anchors.fill: parent
                tone: "elevated"
                radius: Metrics.radiusLarge
            }

            ActiveWindowPill {
                id: activeWindow
                anchors.centerIn: parent
                screen: root.screen
            }
        }
    }
}
