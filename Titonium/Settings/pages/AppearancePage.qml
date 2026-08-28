pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root

    readonly property string mode: Preferences.effectiveState.appearance?.mode || "dark"

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.appearance.title")
            variant: "titleLarge"
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.appearance.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingMedium

            Shared.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                label: I18n.tr("settings.appearance.dark")
                iconName: "dark_mode"
                selected: root.mode === "dark"
                onTriggered: Preferences.patch("appearance.mode", "dark")
            }

            Shared.Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                label: I18n.tr("settings.appearance.light")
                iconName: "light_mode"
                selected: root.mode === "light"
                onTriggered: Preferences.patch("appearance.mode", "light")
            }
        }

        Shared.Panel {
            Layout.fillWidth: true
            Layout.preferredHeight: 104

            RowLayout {
                anchors.fill: parent
                spacing: Metrics.spacingMedium

                Shared.Icon {
                    name: "layers_clear"
                    size: 32
                    tone: "accent"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXSmall

                    Shared.TextLabel {
                        text: I18n.tr("settings.appearance.identity")
                        variant: "titleSmall"
                        strong: true
                    }

                    Shared.TextLabel {
                        text: I18n.tr("settings.appearance.solid")
                        tone: "secondary"
                    }
                }

                Shared.Button {
                    label: I18n.tr("settings.appearance.restore")
                    iconName: "restart_alt"
                    onTriggered: Preferences.restoreAppearance()
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
