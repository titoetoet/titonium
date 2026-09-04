pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.islands
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    readonly property alias pinHitbox: pinSurface
    readonly property alias connectivityHitbox: connectivitySurface
    readonly property alias statusHitbox: statusSurface
    property bool showConnectivityDiagnostics: true
    readonly property int preferredWidth: endRow.implicitWidth
    implicitWidth: endRow.implicitWidth
    implicitHeight: Metrics.widgetHeight

    Row {
        id: endRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: Metrics.barSpacing

        Item {
            id: pinSurface
            width: topbarPin.implicitWidth + Metrics.spacingXSmall * 2
            height: Metrics.widgetHeight

            Shared.Surface {
                anchors.fill: parent
                tone: "elevated"
                radius: Metrics.radiusLarge
            }

            TopbarPin {
                id: topbarPin
                anchors.centerIn: parent
            }
        }

        Item {
            id: connectivitySurface
            width: connectivity.implicitWidth + Metrics.spacingXSmall * 2
            height: Metrics.widgetHeight

            Shared.Surface {
                anchors.fill: parent
                tone: "elevated"
                radius: Metrics.radiusLarge
            }

            ConnectivityPill {
                id: connectivity
                anchors.centerIn: parent
                screen: root.screen
                showDiagnostics: root.showConnectivityDiagnostics
            }
        }

        Item {
            id: statusSurface
            width: status.implicitWidth
            height: Metrics.widgetHeight

            Shared.Surface {
                anchors.fill: parent
                tone: "elevated"
                radius: Metrics.radiusLarge
            }

            StatusPill {
                id: status
                anchors.centerIn: parent
                screen: root.screen
            }
        }
    }
}
