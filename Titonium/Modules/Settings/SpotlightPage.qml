pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root

    readonly property var spotlightState: ConfigStore.previewState.modules?.spotlight || ({})
    function transitionIndex(): int {
        const values = ["slide-fade", "slide", "slide-scale", "none"];
        const index = values.indexOf(root.spotlightState.pageTransition);
        return index < 0 ? 0 : index;
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

            Controls.TextLabel { text: I18n.tr("settings.spotlight.title"); variant: "title_large"; strong: true }
            Controls.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.spotlight.description")
                variant: "body"; tone: "secondary"; wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingLarge

                ColumnLayout {
                    Layout.fillWidth: true
                    Controls.TextLabel { text: I18n.tr("settings.spotlight.transition"); strong: true }
                    Controls.Dropdown {
                        Layout.fillWidth: true
                        model: [
                            { "label": I18n.tr("settings.spotlight.transition.slide_fade"), "value": "slide-fade" },
                            { "label": I18n.tr("settings.spotlight.transition.slide"), "value": "slide" },
                            { "label": I18n.tr("settings.spotlight.transition.slide_scale"), "value": "slide-scale" },
                            { "label": I18n.tr("settings.spotlight.transition.none"), "value": "none" }
                        ]
                        currentIndex: root.transitionIndex()
                        accessibleName: I18n.tr("settings.spotlight.transition")
                        onSelected: (index, value) => ConfigStore.patch("modules.spotlight.pageTransition", value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        Controls.TextLabel { text: I18n.tr("settings.spotlight.transition_duration"); strong: true }
                        Item { Layout.fillWidth: true }
                        Controls.TextLabel {
                            text: (root.spotlightState.transitionDuration || 220) + " ms"
                            variant: "mono"; tone: "accent"
                        }
                    }
                    Controls.Slider {
                        Layout.fillWidth: true
                        from: 80; to: 500; stepSize: 20
                        value: root.spotlightState.transitionDuration || 220
                        enabled: root.spotlightState.pageTransition !== "none"
                        accessibleName: I18n.tr("settings.spotlight.transition_duration")
                        onMoved: value => ConfigStore.patch("modules.spotlight.transitionDuration", Math.round(value))
                    }
                }
            }
        }
    }
}
