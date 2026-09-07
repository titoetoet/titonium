pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Notifications
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property var notification
    property bool showSource: true
    property bool collapsedGroup: false
    signal expandRequested()

    implicitHeight: contentColumn.implicitHeight + Metrics.spacingMedium * 2

    Shared.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusMedium
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.collapsedGroup
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expandRequested()
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Metrics.spacingMedium
        spacing: Metrics.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingMedium

            Shared.SystemIcon {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                sourceName: root.notification.appIcon || ""
                fallbackName: root.notification.category === "timer" ? "timer"
                    : (root.notification.category === "job" ? "work" : "notifications")
                size: 24
                tone: root.notification.severity === "critical" ? "danger" : "accent"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXSmall

                Shared.TextLabel {
                    Layout.fillWidth: true
                    visible: root.showSource
                    text: root.notification.appName
                        || I18n.tr("notification.toast.fallback_app")
                    variant: "caption"
                    tone: "secondary"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.notification.summary || root.notification.appName
                        || I18n.tr("notification.toast.fallback_app")
                    variant: "label"
                    strong: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    visible: String(root.notification.body || "").length > 0
                    text: root.notification.body || ""
                    variant: "bodySmall"
                    tone: "secondary"
                    wrapMode: Text.Wrap
                    maximumLineCount: root.collapsedGroup ? 2 : 4
                    elide: Text.ElideRight
                }
            }

            Shared.Button {
                Layout.alignment: Qt.AlignTop
                size: "small"
                variant: "quiet"
                iconName: "close"
                accessibleName: I18n.tr("notification.panel.dismiss")
                onTriggered: NotificationCoordinator.dismiss(root.notification.key)
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall
            visible: root.notification.actions.length > 0

            Repeater {
                model: root.notification.actions

                Shared.Button {
                    required property var modelData
                    label: modelData.label || I18n.tr("notification.panel.action")
                    size: "small"
                    variant: "secondary"
                    onTriggered: NotificationCoordinator.action(
                        root.notification.key, modelData.id)
                }
            }
        }
    }
}
