pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.components

Item {
    id: root

    readonly property var languageOptions: Object.freeze([
        Object.freeze({ label: "Tiếng Việt", value: "vi" }),
        Object.freeze({ label: "English", value: "en" }),
    ])

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.general.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.borderWidth
            color: Theme.border
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.general.language")

            Shared.Select {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                model: root.languageOptions
                currentIndex: Preferences.locale === "en" ? 1 : 0
                accessibleName: I18n.tr("settings.general.language")
                onSelected: (index, value) => Preferences.patch("locale", value)
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.general.reduced_motion")
            description: I18n.tr("settings.general.reduced_motion.description")

            Shared.Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Preferences.reducedMotion
                accessibleName: I18n.tr("settings.general.reduced_motion")
                onToggled: checked => Preferences.patch("accessibility.reducedMotion", checked)
            }
        }

        Item { Layout.fillHeight: true }
    }
}
