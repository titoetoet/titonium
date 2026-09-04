pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces.Center
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    readonly property var latestNotification: NotificationService.notifications.length > 0
        ? NotificationService.notifications[0] : null

    visible: NotificationService.hasUnread
    implicitWidth: 28
    implicitHeight: Metrics.widgetHeight

    onVisibleChanged: {
        if (!root.visible) {
            wobble.stop();
            bellIcon.rotation = 0;
        }
    }

    Connections {
        target: NotificationService
        function onUnreadCountChanged(): void {
            if (NotificationService.unreadCount > 0 && !Motion.reduced)
                wobble.restart();
        }
    }

    Connections {
        target: Motion
        function onReducedChanged(): void {
            if (Motion.reduced) {
                wobble.stop();
                bellIcon.rotation = 0;
            }
        }
    }

    Shared.Icon {
        id: bellIcon
        anchors.centerIn: parent
        name: "notifications"
        size: 19
        tone: "primary"
        scale: Motion.reduced ? 1 : (bellTap.pressed ? 0.96
            : (bellHover.hovered ? 1.08 : 1))
        transformOrigin: Item.Top
        transform: Translate { y: !Motion.reduced && bellHover.hovered ? -1 : 0 }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.reduced ? 0 : 140
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
            }
        }
    }

    Rectangle {
        anchors.top: bellIcon.top
        anchors.right: bellIcon.right
        anchors.topMargin: -4
        anchors.rightMargin: -6
        width: 14
        height: 14
        radius: 7
        color: Theme.danger

        Text {
            anchors.centerIn: parent
            text: NotificationService.unreadCount > 9
                ? "9+" : String(NotificationService.unreadCount)
            color: "#ffffff"
            font.pixelSize: 8
            font.bold: true
        }
    }

    SequentialAnimation {
        id: wobble
        loops: 3

        NumberAnimation { target: bellIcon; property: "rotation"; from: 0; to: -12; duration: 55 }
        NumberAnimation { target: bellIcon; property: "rotation"; from: -12; to: 12; duration: 90 }
        NumberAnimation { target: bellIcon; property: "rotation"; from: 12; to: 0; duration: 55 }
    }

    HoverHandler { id: bellHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: bellTap
        onTapped: {
            const item = root.latestNotification;
            CenterSurfaceController.dispatch({ type: "request-open",
                screenName: root.screen.name, mode: "banner",
                contextId: item ? "notification:" + item.id : "",
                timeoutMs: 0, focusPolicy: "none" });
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("notification.bell.unread", {
        count: NotificationService.unreadCount
    })
}
