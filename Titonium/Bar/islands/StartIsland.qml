pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.widgets
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen

    implicitWidth: startRow.implicitWidth
    implicitHeight: Metrics.widgetHeight

    Row {
        id: startRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Metrics.spacingSmall

        ArchLogo {}

        Item {
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

        ActiveWindowPill {
            screen: root.screen
        }
    }
}
