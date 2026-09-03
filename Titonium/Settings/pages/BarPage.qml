pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.components

Item {
    id: root

    readonly property int workspaceCount: Preferences.bar.workspaceCount
    readonly property var styleOptions: Object.freeze([
        Object.freeze({ label: I18n.tr("settings.bar.style.connected"), value: "connected" }),
        Object.freeze({ label: I18n.tr("settings.bar.style.classic"), value: "classic" }),
    ])

    function styleIndex(): int {
        return root.styleOptions.findIndex(option => option.value === Preferences.barStyle);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.bar.title")
            variant: "titleLarge"
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.bar.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.bar.style")
            description: I18n.tr("settings.bar.style.description")

            Shared.Select {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                model: root.styleOptions
                currentIndex: Math.max(0, root.styleIndex())
                accessibleName: I18n.tr("settings.bar.style")
                onSelected: (index, value) => Preferences.patch("modules.bar.style", value)
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.bar.workspace_count", { "count": root.workspaceCount })

            Shared.Slider {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                from: 1
                to: 8
                stepSize: 1
                value: root.workspaceCount
                accessibleName: I18n.tr("settings.bar.workspace_count", {
                    "count": root.workspaceCount
                })
                onMoved: value => Preferences.patch("modules.bar.workspaceCount",
                    Math.round(value))
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.bar.auto_hide")
            description: I18n.tr("settings.bar.auto_hide.description")

            Shared.Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Preferences.bar.autoHide === true
                accessibleName: I18n.tr("settings.bar.auto_hide")
                onToggled: checked => Preferences.patch("modules.bar.autoHide", checked)
            }
        }

        SettingRow {
            Layout.fillWidth: true
            title: I18n.tr("settings.bar.mascot")
            description: I18n.tr("settings.bar.mascot.description")

            Shared.Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Preferences.bar.mascotEnabled !== false
                accessibleName: I18n.tr("settings.bar.mascot")
                onToggled: checked => Preferences.patch("modules.bar.mascotEnabled", checked)
            }
        }

        Item { Layout.fillHeight: true }
    }
}
