pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var screen
    signal toggleRequested(var screen, var invoker)
    readonly property string iconName: "history"

    implicitWidth: 28
    implicitHeight: Metrics.widgetHeight

    function activate(): void {
        root.toggleRequested(root.screen, root);
    }

    Rectangle {
        anchors.centerIn: parent
        width: 28
        height: 28
        radius: Metrics.radiusSmall
        color: bellHover.hovered || bellTap.pressed
            ? Theme.surfaceInteractive : "transparent"
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: root.activeFocus ? Theme.focus : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Shared.Icon {
        id: centerIcon
        anchors.centerIn: parent
        name: root.iconName
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
        visible: NotificationCoordinator.hasUnread
        anchors.top: centerIcon.top
        anchors.right: centerIcon.right
        anchors.topMargin: -4
        anchors.rightMargin: -6
        width: 14
        height: 14
        radius: 7
        color: Theme.danger

        Text {
            anchors.centerIn: parent
            text: NotificationCoordinator.unreadCount > 9
                ? "9+" : String(NotificationCoordinator.unreadCount)
            color: "#ffffff"
            font.pixelSize: 8
            font.bold: true
        }
    }

    HoverHandler { id: bellHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: bellTap
        onTapped: root.activate()
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr(NotificationCoordinator.hasUnread
        ? "notification.center.unread" : "notification.center.none", {
        count: NotificationCoordinator.unreadCount
    })
    Accessible.focusable: true
    Accessible.onPressAction: root.activate()
}
