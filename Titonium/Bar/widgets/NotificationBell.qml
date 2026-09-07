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

    Shared.InteractionFeedback {
        anchors.centerIn: parent
        width: 28
        height: 28
        hovered: bellHover.hovered
        pressed: bellTap.pressed
        selected: NotificationCoordinator.panelOpen
        warning: !!NotificationCoordinator.currentCritical
        focused: root.activeFocus
    }

    Shared.Icon {
        id: centerIcon
        anchors.centerIn: parent
        name: root.iconName
        size: 19
        tone: "primary"
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
