pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root

    readonly property var fontOptions: [
        { "label": "SF Pro Display", "value": "SF Pro Display" },
        { "label": "Noto Sans", "value": "Noto Sans" },
        { "label": "Sans Serif", "value": "sans-serif" }
    ]
    readonly property var monoOptions: [
        { "label": "JetBrains Mono", "value": "JetBrains Mono" },
        { "label": "SF Mono", "value": "SF Mono" },
        { "label": "Noto Sans Mono", "value": "Noto Sans Mono" }
    ]

    function optionIndex(options: var, value: string): int {
        for (let index = 0; index < options.length; index++) {
            if (options[index].value === value)
                return index;
        }
        return 0;
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: parent.width
            spacing: Metrics.spacingLarge

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingXSmall

                Controls.TextLabel {
                    text: I18n.tr("settings.typography.title")
                    variant: "title_large"
                    strong: true
                }

                Controls.TextLabel {
                    text: I18n.tr("settings.typography.description")
                    variant: "body"
                    tone: "secondary"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingLarge

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingSmall

                    Controls.TextLabel {
                        text: I18n.tr("settings.typography.ui_font")
                        variant: "label"
                        strong: true
                    }

                    Controls.Dropdown {
                        Layout.fillWidth: true
                        model: root.fontOptions
                        currentIndex: root.optionIndex(root.fontOptions, Typography.fontFamily)
                        accessibleName: I18n.tr("settings.typography.ui_font")
                        onSelected: (index, value) => ConfigStore.patch("appearance.overrides.typography.fontFamily", value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingSmall

                    Controls.TextLabel {
                        text: I18n.tr("settings.typography.mono_font")
                        variant: "label"
                        strong: true
                    }

                    Controls.Dropdown {
                        Layout.fillWidth: true
                        model: root.monoOptions
                        currentIndex: root.optionIndex(root.monoOptions, Typography.monoFamily)
                        accessibleName: I18n.tr("settings.typography.mono_font")
                        onSelected: (index, value) => ConfigStore.patch("appearance.overrides.typography.monoFamily", value)
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    Controls.TextLabel { text: I18n.tr("settings.typography.body_size"); strong: true }
                    Item { Layout.fillWidth: true }
                    Controls.TextLabel { text: Typography.bodySize + " px"; variant: "mono"; tone: "accent" }
                }

                Controls.Slider {
                    Layout.fillWidth: true
                    from: 11
                    to: 18
                    stepSize: 1
                    value: Typography.bodySize
                    accessibleName: I18n.tr("settings.typography.body_size")
                    onMoved: value => ConfigStore.patch("appearance.overrides.typography.bodySize", Math.round(value))
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    Controls.TextLabel { text: I18n.tr("settings.typography.title_size"); strong: true }
                    Item { Layout.fillWidth: true }
                    Controls.TextLabel { text: Typography.titleSize + " px"; variant: "mono"; tone: "accent" }
                }

                Controls.Slider {
                    Layout.fillWidth: true
                    from: 14
                    to: 24
                    stepSize: 1
                    value: Typography.titleSize
                    accessibleName: I18n.tr("settings.typography.title_size")
                    onMoved: value => ConfigStore.patch("appearance.overrides.typography.titleSize", Math.round(value))
                }
            }

            Controls.Card {
                Layout.fillWidth: true
                implicitWidth: 1
                implicitHeight: 150
                interactive: false

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Metrics.spacingSmall

                    Controls.TextLabel {
                        text: I18n.tr("settings.typography.preview")
                        variant: "caption"
                        tone: "secondary"
                        strong: true
                    }

                    Controls.TextLabel {
                        text: "Titonium Neutral Utility"
                        variant: "display"
                        strong: true
                    }

                    Controls.TextLabel {
                        text: I18n.tr("settings.typography.preview_body")
                        variant: "body"
                    }

                    Controls.TextLabel {
                        text: "Aa 0123456789 · const theme = solid;"
                        variant: "mono"
                        tone: "accent"
                    }
                }
            }

            Controls.Button {
                label: I18n.tr("settings.typography.reset")
                iconName: "restart_alt"
                variant: "secondary"
                onTriggered: ConfigStore.patch("appearance.overrides.typography", {})
            }
        }
    }
}
