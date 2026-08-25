pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root
    readonly property var audioState: ConfigStore.previewState.modules?.audio || ({})

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            width: parent.width
            spacing: Metrics.spacingLarge

            Controls.TextLabel { text: I18n.tr("settings.audio.title"); variant: "title_large"; strong: true }
            Controls.TextLabel {
                text: I18n.tr("settings.audio.description")
                variant: "body"
                tone: "secondary"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Controls.TextLabel { text: I18n.tr("settings.audio.volume_step"); strong: true }
                Item { Layout.fillWidth: true }
                Controls.TextLabel { text: (root.audioState.volumeStep || 5) + "%"; variant: "mono"; tone: "accent" }
            }
            Controls.Slider {
                Layout.fillWidth: true
                from: 1; to: 20; stepSize: 1
                value: root.audioState.volumeStep || 5
                accessibleName: I18n.tr("settings.audio.volume_step")
                onMoved: value => ConfigStore.patch("modules.audio.volumeStep", Math.round(value))
            }

            RowLayout {
                Layout.fillWidth: true
                Controls.TextLabel { text: I18n.tr("settings.audio.max_volume"); strong: true }
                Item { Layout.fillWidth: true }
                Controls.TextLabel { text: (root.audioState.maxVolume || 100) + "%"; variant: "mono"; tone: "accent" }
            }
            Controls.Slider {
                Layout.fillWidth: true
                from: 50; to: 150; stepSize: 5
                value: root.audioState.maxVolume || 100
                accessibleName: I18n.tr("settings.audio.max_volume")
                onMoved: value => ConfigStore.patch("modules.audio.maxVolume", Math.round(value))
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: Metrics.borderWidth; color: Theme.border }

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Controls.TextLabel { text: I18n.tr("settings.audio.visualizer"); strong: true }
                    Controls.TextLabel {
                        text: I18n.tr("settings.audio.visualizer_deferred")
                        variant: "caption"; tone: "secondary"
                    }
                }
                Controls.Switch {
                    checked: root.audioState.visualizerEnabled === true
                    accessibleName: I18n.tr("settings.audio.visualizer")
                    onToggled: checked => ConfigStore.patch("modules.audio.visualizerEnabled", checked)
                }
            }

            Controls.Tabs {
                enabled: root.audioState.visualizerEnabled === true
                model: [
                    { "label": I18n.tr("settings.audio.bars"), "value": "bars" },
                    { "label": I18n.tr("settings.audio.wave"), "value": "wave" },
                    { "label": I18n.tr("settings.audio.dots"), "value": "dots" }
                ]
                currentIndex: root.audioState.visualizerStyle === "wave" ? 1 : (root.audioState.visualizerStyle === "dots" ? 2 : 0)
                accessibleName: I18n.tr("settings.audio.style")
                onActivated: (index, value) => ConfigStore.patch("modules.audio.visualizerStyle", value)
            }

            RowLayout {
                Layout.fillWidth: true
                enabled: root.audioState.visualizerEnabled === true
                opacity: enabled ? 1.0 : 0.45
                Controls.TextLabel { text: I18n.tr("settings.audio.bar_count"); strong: true }
                Item { Layout.fillWidth: true }
                Controls.TextLabel { text: String(root.audioState.visualizerBars || 32); variant: "mono"; tone: "accent" }
            }
            Controls.Slider {
                Layout.fillWidth: true
                enabled: root.audioState.visualizerEnabled === true
                from: 16; to: 64; stepSize: 4
                value: root.audioState.visualizerBars || 32
                accessibleName: I18n.tr("settings.audio.bar_count")
                onMoved: value => ConfigStore.patch("modules.audio.visualizerBars", Math.round(value))
            }

            Controls.Button {
                label: I18n.tr("settings.audio.reset")
                iconName: "restart_alt"
                variant: "secondary"
                onTriggered: ConfigStore.patch("modules.audio", ConfigStore.shippedDefaults.modules.audio)
            }
        }
    }
}
