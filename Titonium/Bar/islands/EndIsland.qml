pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

Item {
    id: root
    required property var screen
    property bool showConnectivityDiagnostics: true
    readonly property int preferredWidth: connectivity.implicitWidth + Metrics.barSpacing
        + status.implicitWidth

    implicitWidth: endRow.implicitWidth
    implicitHeight: Metrics.widgetHeight

    Row {
        id: endRow
        anchors.fill: parent
        spacing: connectivity.visible ? Metrics.barSpacing : 0

        ConnectivityPill {
            id: connectivity
            showDiagnostics: root.showConnectivityDiagnostics
        }
        StatusPill {
            id: status
            screen: root.screen
        }
    }
}
