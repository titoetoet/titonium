pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root

    readonly property string themeId: ConfigStore.previewState.appearance?.themeId || ThemeCatalog.defaultThemeId
    readonly property string mode: ConfigStore.previewState.appearance?.mode || "dark"
    readonly property string density: ConfigStore.previewState.appearance?.density || "comfortable"

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXSmall

            Controls.TextLabel {
                text: I18n.tr("settings.theme.title")
                variant: "title_large"
                strong: true
            }

            Controls.TextLabel {
                text: I18n.tr("settings.theme.description")
                variant: "body"
                tone: "secondary"
            }
        }

        Controls.TextLabel {
            text: I18n.tr("settings.theme.packages")
            variant: "title_small"
            strong: true
        }

        Repeater {
            model: ThemeCatalog.availableThemes

            Controls.Card {
                id: themeCard
                required property var modelData
                Layout.fillWidth: true
                implicitWidth: 1
                implicitHeight: 92
                interactive: true
                selected: root.themeId === modelData.id
                accessibleName: I18n.tr(modelData.nameKey)
                onTriggered: ConfigStore.patch("appearance.themeId", modelData.id)

                RowLayout {
                    anchors.fill: parent
                    spacing: Metrics.spacingMedium

                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Metrics.radiusMedium
                        color: Theme.surfaceInteractive
                        border.width: Metrics.borderWidth
                        border.color: Theme.border

                        Rectangle {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            radius: width / 2
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingXSmall

                        Controls.TextLabel {
                            text: I18n.tr(themeCard.modelData.nameKey)
                            variant: "title"
                            strong: true
                        }

                        Controls.TextLabel {
                            Layout.fillWidth: true
                            text: I18n.tr(themeCard.modelData.descriptionKey || "theme.neutral.description")
                            variant: "body"
                            tone: "secondary"
                            wrapMode: Text.WordWrap
                        }
                    }

                    Controls.Icon {
                        name: root.themeId === themeCard.modelData.id ? "check_circle" : "circle"
                        size: 22
                        tone: root.themeId === themeCard.modelData.id ? "accent" : "secondary"
                        accessibleName: ""
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingLarge

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                Controls.TextLabel {
                    text: I18n.tr("settings.theme.mode")
                    variant: "title_small"
                    strong: true
                }

                Controls.Tabs {
                    model: [
                        { "label": I18n.tr("settings.theme.dark"), "icon": "dark_mode", "value": "dark" },
                        { "label": I18n.tr("settings.theme.light"), "icon": "light_mode", "value": "light" }
                    ]
                    currentIndex: root.mode === "light" ? 1 : 0
                    accessibleName: I18n.tr("settings.theme.mode")
                    onActivated: (index, value) => ConfigStore.patch("appearance.mode", value)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                Controls.TextLabel {
                    text: I18n.tr("settings.theme.density")
                    variant: "title_small"
                    strong: true
                }

                Controls.Tabs {
                    model: [
                        { "label": I18n.tr("settings.theme.comfortable"), "value": "comfortable" },
                        { "label": I18n.tr("settings.theme.compact"), "value": "compact" }
                    ]
                    currentIndex: root.density === "compact" ? 1 : 0
                    accessibleName: I18n.tr("settings.theme.density")
                    onActivated: (index, value) => ConfigStore.patch("appearance.density", value)
                }
            }
        }

        Controls.Surface {
            Layout.fillWidth: true
            implicitWidth: 1
            implicitHeight: 72
            tone: "elevated"
            radius: Metrics.radiusMedium
            outlined: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: Metrics.spacingMedium
                spacing: Metrics.spacingMedium

                Controls.Icon {
                    name: root.themeId === "titonium-neutral" ? "layers_clear" : "blur_on"
                    tone: "accent"
                    accessibleName: ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Controls.TextLabel {
                        text: I18n.tr("settings.theme.material")
                        variant: "body"
                        strong: true
                    }

                    Controls.TextLabel {
                        text: root.themeId === "titonium-neutral"
                            ? I18n.tr("settings.theme.material_solid")
                            : I18n.tr("settings.theme.material_hybrid")
                        variant: "caption"
                        tone: "secondary"
                    }
                }

                Controls.TextLabel {
                    text: (ConfigStore.themeState.material?.defaultBackend || "solid").toUpperCase()
                    variant: "mono"
                    tone: "accent"
                    strong: true
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
