pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Column {
    id: root

    spacing: Metrics.spacingSmall
    z: 100

    Controls.TextLabel {
        text: I18n.tr("gallery.inputs")
        variant: "label"
        strong: true
    }

    Row {
        spacing: Metrics.spacingLarge

        Column {
            width: 180
            spacing: Metrics.spacingXSmall

            Controls.TextLabel { text: I18n.tr("gallery.switch.label"); variant: "caption"; tone: "secondary" }
            Row {
                spacing: Metrics.spacingSmall
                Controls.Switch {
                    id: sampleSwitch
                    checked: true
                    accessibleName: I18n.tr("gallery.switch.accessible")
                }
                Controls.TextLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sampleSwitch.checked ? I18n.tr("gallery.state.on") : I18n.tr("gallery.state.off")
                    variant: "label"
                }
                Controls.Switch {
                    checked: false
                    enabled: false
                    accessibleName: I18n.tr("gallery.disabled")
                }
            }
        }

        Column {
            width: 300
            spacing: Metrics.spacingXSmall

            Item {
                width: parent.width
                height: sliderLabel.implicitHeight
                Controls.TextLabel {
                    id: sliderLabel
                    anchors.left: parent.left
                    text: I18n.tr("gallery.slider.label")
                    variant: "caption"
                    tone: "secondary"
                }
                Controls.TextLabel {
                    anchors.right: parent.right
                    text: Math.round(sampleSlider.value) + "%"
                    variant: "mono"
                    tone: "secondary"
                }
            }
            Controls.Slider {
                id: sampleSlider
                width: parent.width
                from: 0
                to: 100
                value: 68
                stepSize: 1
                accessibleName: I18n.tr("gallery.slider.accessible")
            }
        }

        Column {
            width: 240
            spacing: Metrics.spacingXSmall

            Controls.TextLabel { text: I18n.tr("gallery.dropdown.label"); variant: "caption"; tone: "secondary" }
            Controls.Dropdown {
                width: parent.width
                model: [
                    { label: I18n.tr("gallery.density.comfortable"), value: "comfortable" },
                    { label: I18n.tr("gallery.density.compact"), value: "compact" },
                    { label: I18n.tr("gallery.density.large"), value: "large" }
                ]
                currentIndex: 0
                accessibleName: I18n.tr("gallery.dropdown.accessible")
            }
        }
    }
}
