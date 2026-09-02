pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    signal notificationsRequested()
    width: 24
    height: 24
    readonly property string accessibleName: NotificationService.hasUnread
        ? I18n.tr("notification.bell.unread", {
            "count": NotificationService.unreadCount
        }) : I18n.tr("notification.bell.none")

    Shared.Button {
        anchors.fill: parent
        iconName: "notifications"
        variant: "quiet"
        size: "small"
        showFocusRing: false
        backgroundRadius: Metrics.radiusLarge
        accessibleName: root.accessibleName
        onTriggered: root.notificationsRequested()
    }

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        width: 6
        height: 6
        radius: 3
        color: Theme.accent
        visible: NotificationService.hasUnread
    }
}
