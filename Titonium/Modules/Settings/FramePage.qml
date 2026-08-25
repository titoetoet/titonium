pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import qs.Titonium.Modules.Frame

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingXSmall

            Controls.TextLabel {
                text: I18n.tr("settings.frame.title")
                variant: "title_large"
                strong: true
            }

            Controls.TextLabel {
                text: I18n.tr("settings.frame.description")
                variant: "body"
                tone: "secondary"
            }
        }

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Controls.TextLabel { text: I18n.tr("settings.frame.enable"); strong: true }
                Controls.TextLabel {
                    text: I18n.tr("settings.frame.enable_description")
                    variant: "caption"
                    tone: "secondary"
                }
            }

            Controls.Switch {
                checked: FrameModel.enabled
                accessibleName: I18n.tr("settings.frame.enable")
                onToggled: checked => ConfigStore.patch("modules.frame.enabled", checked)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall
            enabled: FrameModel.enabled
            opacity: enabled ? 1.0 : 0.45

            RowLayout {
                Layout.fillWidth: true
                Controls.TextLabel { text: I18n.tr("settings.frame.thickness"); strong: true }
                Item { Layout.fillWidth: true }
                Controls.TextLabel { text: FrameModel.thickness + " px"; variant: "mono"; tone: "accent" }
            }

            Controls.Slider {
                Layout.fillWidth: true
                from: 1
                to: 8
                stepSize: 1
                value: FrameModel.thickness
                accessibleName: I18n.tr("settings.frame.thickness")
                onMoved: value => ConfigStore.patch("modules.frame.thickness", Math.round(value))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall
            enabled: FrameModel.enabled
            opacity: enabled ? 1.0 : 0.45

            RowLayout {
                Layout.fillWidth: true
                Controls.TextLabel { text: I18n.tr("settings.frame.radius"); strong: true }
                Item { Layout.fillWidth: true }
                Controls.TextLabel { text: FrameModel.cornerRadius + " px"; variant: "mono"; tone: "accent" }
            }

            Controls.Slider {
                Layout.fillWidth: true
                from: 0
                to: 32
                stepSize: 1
                value: FrameModel.cornerRadius
                accessibleName: I18n.tr("settings.frame.radius")
                onMoved: value => ConfigStore.patch("modules.frame.cornerRadius", Math.round(value))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall
            enabled: FrameModel.enabled
            opacity: enabled ? 1.0 : 0.45

            RowLayout {
                Layout.fillWidth: true
                Controls.TextLabel { text: I18n.tr("settings.frame.opacity"); strong: true }
                Item { Layout.fillWidth: true }
                Controls.TextLabel { text: Math.round(FrameModel.opacity * 100) + "%"; variant: "mono"; tone: "accent" }
            }

            Controls.Slider {
                Layout.fillWidth: true
                from: 0.3
                to: 1.0
                stepSize: 0.05
                value: FrameModel.opacity
                accessibleName: I18n.tr("settings.frame.opacity")
                onMoved: value => ConfigStore.patch("modules.frame.opacity", Math.round(value * 100) / 100)
            }
        }

        Controls.Surface {
            Layout.fillWidth: true
            implicitWidth: 1
            implicitHeight: 92
            tone: "elevated"
            radius: Metrics.radiusMedium
            outlined: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: Metrics.spacingMedium
                color: "transparent"
                radius: FrameModel.cornerRadius / 2
                border.width: FrameModel.enabled ? FrameModel.thickness : 1
                border.color: FrameModel.enabled
                    ? Qt.alpha(Theme.borderStrong, FrameModel.opacity)
                    : Theme.border

                Controls.TextLabel {
                    anchors.centerIn: parent
                    text: I18n.tr("settings.frame.preview")
                    variant: "caption"
                    tone: "secondary"
                }
            }
        }

        Controls.Button {
            label: I18n.tr("settings.frame.reset")
            iconName: "restart_alt"
            variant: "secondary"
            onTriggered: ConfigStore.patch("modules.frame", ConfigStore.shippedDefaults.modules.frame)
        }

        Item { Layout.fillHeight: true }
    }
}
