pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "../../Services/Notifications/NotificationRules.js" as NotificationRules

Shared.Surface {
    id: root

    required property var notification
    required property double observedAt
    signal dismissRequested(int notificationId)

    readonly property var age: NotificationRules.relativeAge(
        root.notification.receivedAt, root.observedAt)
    readonly property string ageText: {
        if (!root.age || root.age.unit === "now")
            return I18n.tr("center_notch.notifications.time_now");
        return I18n.tr("center_notch.notifications.time_" + root.age.unit, {
            "count": root.age.count
        });
    }

    implicitHeight: Math.max(80, contentRow.implicitHeight + Metrics.spacingMedium * 2)
    tone: "elevated"
    radius: Metrics.radiusMedium
    padding: Metrics.spacingMedium
    borderColor: root.notification.urgency === 2 ? Theme.danger : Theme.border

    RowLayout {
        id: contentRow
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        Shared.SystemIcon {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            sourceName: root.notification.appIcon || ""
            fallbackName: "notifications"
            size: 28
            tone: root.notification.urgency === 2 ? "danger"
                : (root.notification.urgency === 1 ? "accent" : "secondary")
            accessibleName: root.notification.appName
                || I18n.tr("notification.toast.fallback_app")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.notification.appName
                        || I18n.tr("notification.toast.fallback_app")
                    variant: "caption"
                    tone: "secondary"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Shared.TextLabel {
                    text: root.ageText
                    variant: "caption"
                    tone: "secondary"
                }
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                text: root.notification.summary || root.notification.appName
                    || I18n.tr("notification.toast.fallback_app")
                variant: "label"
                strong: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.notification.body.length > 0
                text: root.notification.body
                variant: "body"
                tone: "secondary"
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 3
            }
        }

        Shared.Button {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            iconName: "close"
            size: "small"
            variant: "quiet"
            showFocusRing: false
            backgroundRadius: Metrics.radiusLarge
            accessibleName: I18n.tr("center_notch.notifications.dismiss")
            onTriggered: root.dismissRequested(root.notification.id)
        }
    }
}
