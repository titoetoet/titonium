pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

Item {
    id: root
    required property var screen
    property bool showConnectivityDiagnostics: true
    readonly property int preferredWidth: notification.implicitWidth + Metrics.barSpacing
        + connectivity.fullImplicitWidth + Metrics.barSpacing + status.implicitWidth

    implicitWidth: endRow.implicitWidth
    implicitHeight: Metrics.widgetHeight

    Row {
        id: endRow
        anchors.fill: parent
        spacing: Metrics.barSpacing

        NotificationPill {
            id: notification
        }

        ConnectivityPill {
            id: connectivity
            screen: root.screen
            showDiagnostics: root.showConnectivityDiagnostics
        }
        StatusPill {
            id: status
            screen: root.screen
        }
    }
}
