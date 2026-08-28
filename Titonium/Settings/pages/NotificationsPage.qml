pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.components

Item {
    id: root

    readonly property bool toastsEnabled: Preferences.notifications.toastsEnabled !== false
    readonly property int toastDuration: Preferences.notifications.toastDuration || 5000

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.notifications.title")
            variant: "titleLarge"
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.notifications.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.notifications.toasts")

            Shared.Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.toastsEnabled
                accessibleName: I18n.tr("settings.notifications.toasts")
                onToggled: checked => Preferences.patch("modules.notifications.toastsEnabled", checked)
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.notifications.duration", {
                "seconds": (root.toastDuration / 1000).toFixed(1)
            })

            Shared.Slider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                from: 2000
                to: 10000
                stepSize: 500
                value: root.toastDuration
                enabled: root.toastsEnabled
                accessibleName: I18n.tr("settings.notifications.duration", {
                    "seconds": (root.toastDuration / 1000).toFixed(1)
                })
                onMoved: value => Preferences.patch("modules.notifications.toastDuration",
                    Math.round(value))
            }
        }

        Item { Layout.fillHeight: true }
    }
}
