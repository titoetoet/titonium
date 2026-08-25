pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root

    readonly property var menubar: ConfigStore.previewLayout.menubar || ({})
    readonly property var slots: menubar.screens?.default?.slots || ({})

    function slotSummary(slotName: string): string {
        const nodes = root.slots[slotName] || [];
        if (nodes.length === 0)
            return I18n.tr("settings.layout.empty");
        return nodes.map(node => node.widgetType || node.type).join(" · ");
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
                    text: I18n.tr("settings.layout.title")
                    variant: "title_large"
                    strong: true
                }

                Controls.TextLabel {
                    text: I18n.tr("settings.layout.description")
                    variant: "body"
                    tone: "secondary"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    Controls.TextLabel { text: I18n.tr("settings.layout.height"); strong: true }
                    Item { Layout.fillWidth: true }
                    Controls.TextLabel { text: root.menubar.height + " px"; variant: "mono"; tone: "accent" }
                }

                Controls.Slider {
                    Layout.fillWidth: true
                    from: 32
                    to: 52
                    stepSize: 1
                    value: root.menubar.height || 40
                    accessibleName: I18n.tr("settings.layout.height")
                    onMoved: value => ConfigStore.patchLayout("menubar.height", Math.round(value))
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingLarge

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true
                        Controls.TextLabel { text: I18n.tr("settings.layout.padding"); strong: true }
                        Item { Layout.fillWidth: true }
                        Controls.TextLabel { text: (root.menubar.padding ?? 8) + " px"; variant: "mono"; tone: "accent" }
                    }

                    Controls.Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 16
                        stepSize: 1
                        value: root.menubar.padding ?? 8
                        accessibleName: I18n.tr("settings.layout.padding")
                        onMoved: value => ConfigStore.patchLayout("menubar.padding", Math.round(value))
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingSmall

                    RowLayout {
                        Layout.fillWidth: true
                        Controls.TextLabel { text: I18n.tr("settings.layout.spacing"); strong: true }
                        Item { Layout.fillWidth: true }
                        Controls.TextLabel { text: (root.menubar.spacing ?? 8) + " px"; variant: "mono"; tone: "accent" }
                    }

                    Controls.Slider {
                        Layout.fillWidth: true
                        from: 0
                        to: 16
                        stepSize: 1
                        value: root.menubar.spacing ?? 8
                        accessibleName: I18n.tr("settings.layout.spacing")
                        onMoved: value => ConfigStore.patchLayout("menubar.spacing", Math.round(value))
                    }
                }
            }

            Controls.TextLabel {
                text: I18n.tr("settings.layout.composition")
                variant: "title_small"
                strong: true
            }

            Repeater {
                model: ["start", "center", "end"]

                Controls.Card {
                    id: slotCard
                    required property string modelData
                    Layout.fillWidth: true
                    implicitWidth: 1
                    implicitHeight: 58
                    interactive: false

                    RowLayout {
                        anchors.fill: parent

                        Controls.TextLabel {
                            text: I18n.tr("settings.layout.slot." + slotCard.modelData)
                            variant: "label"
                            strong: true
                            Layout.preferredWidth: 84
                        }

                        Controls.TextLabel {
                            Layout.fillWidth: true
                            text: root.slotSummary(slotCard.modelData)
                            variant: "caption"
                            tone: "secondary"
                            elide: Text.ElideRight
                        }

                        Controls.TextLabel {
                            text: String((root.slots[slotCard.modelData] || []).length)
                            variant: "mono"
                            tone: "accent"
                        }
                    }
                }
            }

            Controls.Button {
                label: I18n.tr("settings.layout.reset")
                iconName: "restart_alt"
                variant: "secondary"
                onTriggered: ConfigStore.restoreLayout()
            }
        }
    }
}
