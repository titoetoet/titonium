pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "../Services/Notifications/NotificationRules.js" as NotificationRules

Item {
    id: root

    readonly property real implicitContentWidth: 420
    readonly property var groups: NotificationRules.historyGroups(NotificationCoordinator.history)
    property var expandedGroups: ({})
    function toggleGroup(key: string): void {
        const next = Object.assign({}, root.expandedGroups);
        next[key] = !next[key];
        root.expandedGroups = next;
    }
    readonly property real listHeight: NotificationCoordinator.history.length === 0
        ? 112 : 560
    readonly property real implicitContentHeight: headerRow.implicitHeight + Metrics.borderWidth
        + root.listHeight + Metrics.spacingMedium * 2
    implicitWidth: root.implicitContentWidth
    implicitHeight: root.implicitContentHeight

    signal dismissRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: Metrics.spacingMedium

            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("notification.panel.title")
                variant: "title"
                strong: true
                Accessible.role: Accessible.Heading
            }

            Shared.Button {
                visible: NotificationCoordinator.history.length > 0
                accessibleName: I18n.tr("notification.panel.clear_all")
                iconName: "clear_all"
                variant: "quiet"
                size: "small"
                onTriggered: NotificationCoordinator.dismissAll()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.borderWidth
            color: Theme.border
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.listHeight
            Layout.minimumHeight: 0

            ListView {
                id: historyList
                anchors.fill: parent
                model: root.groups
                clip: true
                spacing: Metrics.spacingSmall
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true

                delegate: NotificationHistoryGroup {
                    required property var modelData
                    width: historyList.width
                    group: modelData
                    expanded: root.expandedGroups[modelData.key] === true
                    onToggleRequested: root.toggleGroup(modelData.key)
                }
            }

            Shared.TextLabel {
                anchors.centerIn: parent
                visible: NotificationCoordinator.history.length === 0
                text: I18n.tr("notification.panel.empty")
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
