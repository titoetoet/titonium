pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.widgets
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    signal notificationsRequested()
    visible: NotificationService.hasUnread
    implicitWidth: root.visible ? notificationBell.width + Metrics.spacingXSmall * 2 : 0
    implicitHeight: Metrics.widgetHeight

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusLarge
    }

    NotificationBell {
        id: notificationBell
        anchors.centerIn: parent
        onNotificationsRequested: root.notificationsRequested()
    }
}
