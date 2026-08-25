pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import qs.Titonium.Platform

Item {
    id: root

    readonly property var policy: ConfigStore.themeState.material || ({})
    readonly property string backend: policy.defaultBackend || "auto"

    function backendIndex(): int {
        const values = ["auto", "qml", "solid", "native"];
        const index = values.indexOf(root.backend);
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

            Controls.TextLabel { text: I18n.tr("settings.material.title"); variant: "title_large"; strong: true }
            Controls.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.material.description")
                variant: "body"; tone: "secondary"; wrapMode: Text.WordWrap
            }

            Controls.TextLabel { text: I18n.tr("settings.material.backend"); strong: true }
            Controls.Tabs {
                model: [
                    { "label": "Auto", "value": "auto" },
                    { "label": "QML", "value": "qml" },
                    { "label": "Solid", "value": "solid" },
                    { "label": "Native", "value": "native" }
                ]
                currentIndex: root.backendIndex()
                accessibleName: I18n.tr("settings.material.backend")
                onActivated: (index, value) => ConfigStore.patch("appearance.overrides.material.defaultBackend", value)
            }

            Controls.Surface {
                Layout.fillWidth: true
                implicitWidth: 1; implicitHeight: 72
                materialBackend: "qml"
                radius: Metrics.radiusMedium; outlined: true
                RowLayout {
                    anchors.fill: parent; anchors.margins: Metrics.spacingMedium
                    Controls.Icon {
                        name: Capabilities.nativeGlassAvailable ? "verified" : "info"
                        tone: Capabilities.nativeGlassAvailable ? "success" : "warning"
                        accessibleName: ""
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Controls.TextLabel {
                            text: Capabilities.nativeGlassAvailable
                                ? I18n.tr("settings.material.native_ready")
                                : I18n.tr("settings.material.native_unavailable")
                            strong: true
                        }
                        Controls.TextLabel {
                            text: I18n.tr("settings.material.fallback_hint")
                            variant: "caption"; tone: "secondary"; wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Repeater {
                model: [
                    { "key": "opacity", "labelKey": "settings.material.opacity", "fallback": 0.82 },
                    { "key": "tintOpacity", "labelKey": "settings.material.tint", "fallback": 0.78 },
                    { "key": "borderOpacity", "labelKey": "settings.material.border", "fallback": 0.72 },
                    { "key": "specularOpacity", "labelKey": "settings.material.specular", "fallback": 0.22 }
                ]

                ColumnLayout {
                    id: materialControl
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXSmall

                    RowLayout {
                        Layout.fillWidth: true
                        Controls.TextLabel { text: I18n.tr(materialControl.modelData.labelKey); strong: true }
                        Item { Layout.fillWidth: true }
                        Controls.TextLabel {
                            text: Math.round((root.policy[materialControl.modelData.key] ?? materialControl.modelData.fallback) * 100) + "%"
                            variant: "mono"; tone: "accent"
                        }
                    }
                    Controls.Slider {
                        Layout.fillWidth: true
                        from: 0; to: 1; stepSize: 0.05
                        value: root.policy[materialControl.modelData.key] ?? materialControl.modelData.fallback
                        accessibleName: I18n.tr(materialControl.modelData.labelKey)
                        onMoved: value => ConfigStore.patch("appearance.overrides.material." + materialControl.modelData.key,
                            Math.round(value * 100) / 100)
                    }
                }
            }

            Controls.Button {
                label: I18n.tr("settings.material.reset")
                iconName: "restart_alt"; variant: "secondary"
                onTriggered: ConfigStore.patch("appearance.overrides.material", ({}))
            }
        }
    }
}
