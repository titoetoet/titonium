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

    implicitWidth: 28
    implicitHeight: Metrics.widgetHeight
    activeFocusOnTab: true

    function activate(): void {
        root.toggleRequested(root.screen, root);
    }

    Connections {
        target: NotificationCoordinator
        function onUnreadCountChanged(): void {
            if (NotificationCoordinator.unreadCount > 0 && !Motion.reduced)
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
        visible: NotificationCoordinator.hasUnread
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
            text: NotificationCoordinator.unreadCount > 9
                ? "9+" : String(NotificationCoordinator.unreadCount)
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
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr(NotificationCoordinator.hasUnread
        ? "notification.bell.unread" : "notification.bell.none", {
        count: NotificationCoordinator.unreadCount
    })
    Accessible.focusable: true
    Accessible.onPressAction: root.activate()
}
