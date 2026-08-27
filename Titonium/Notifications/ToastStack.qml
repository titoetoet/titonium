pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Services.Notifications
import qs.Titonium.Theme

Item {
    id: root
    required property ShellScreen screenModel

    width: 360
    implicitHeight: toastColumn.implicitHeight

    Column {
        id: toastColumn
        width: parent.width
        spacing: Metrics.spacingSmall

        Repeater {
            model: NotificationService.toastNotifications

            delegate: ToastCard {
                required property var modelData
                notification: modelData
            }
        }
    }
}
