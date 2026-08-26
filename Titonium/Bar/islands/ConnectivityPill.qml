pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    property bool showDiagnostics: true
    readonly property int fullImplicitWidth: iconRow.implicitWidth + Metrics.spacingSmall * 2

    implicitWidth: root.showDiagnostics ? root.fullImplicitWidth : 0
    implicitHeight: Metrics.widgetHeight
    visible: root.showDiagnostics

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusSmall
    }

    Row {
        id: iconRow
        anchors.centerIn: parent
        spacing: Metrics.spacingSmall

        Shared.Icon {
            name: "wifi"
            size: 18
            tone: "secondary"
            accessibleName: I18n.tr("menubar.connectivity.network_planned")
        }
        Shared.Icon {
            name: "bluetooth"
            size: 18
            tone: "secondary"
            accessibleName: I18n.tr("menubar.connectivity.bluetooth_planned")
        }
        Shared.Icon {
            name: "volume_up"
            size: 18
            tone: "secondary"
            accessibleName: I18n.tr("menubar.connectivity.audio_planned")
        }
    }
}
