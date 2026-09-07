pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.components

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.audio.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.audio.amplification")
            description: I18n.tr("settings.audio.amplification.description")

            Shared.Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Preferences.allowAudioAmplification
                accessibleName: I18n.tr("settings.audio.amplification")
                onToggled: checked => Preferences.patch("modules.audio.allowAmplification", checked)
            }
        }

        Item { Layout.fillHeight: true }
    }
}
