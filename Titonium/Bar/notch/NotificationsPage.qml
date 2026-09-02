pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property string pageId: "notifications"
    property double observedAt: Date.now()

    function markVisibleNotificationsRead(): void {
        root.observedAt = Date.now();
        if (NotificationService.unreadCount > 0)
            NotificationService.markAllRead();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingMedium

            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("center_notch.notifications.title")
                variant: "title"
                strong: true
            }

            Shared.TextLabel {
                visible: NotificationService.unreadCount > 0
                text: I18n.tr("center_notch.notifications.unread_header", {
                    "count": NotificationService.unreadCount
                })
                variant: "caption"
                tone: "secondary"
            }

            Shared.Button {
                label: I18n.tr("center_notch.notifications.clear_all")
                iconName: "clear_all"
                size: "small"
                variant: "secondary"
                enabled: NotificationService.notifications.length > 0
                accessibleName: I18n.tr("center_notch.notifications.clear_all")
                onTriggered: NotificationService.dismissAll()
            }
        }

        QtControls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ListView {
                id: historyList
                width: parent.width
                spacing: Metrics.spacingSmall
                model: NotificationService.notifications
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true

                delegate: NotificationHistoryRow {
                    required property var modelData
                    width: historyList.width
                    notification: modelData
                    observedAt: root.observedAt
                    onDismissRequested: id => NotificationService.dismiss(id)
                }
            }
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.notifications.length === 0
            text: I18n.tr("center_notch.notifications.empty")
            tone: "secondary"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    Connections {
        target: NotificationService

        function onUnreadCountChanged(): void {
            root.markVisibleNotificationsRead();
        }

        function onNotificationsChanged(): void {
            root.observedAt = Date.now();
        }
    }

    Component.onCompleted: root.markVisibleNotificationsRead()
}
