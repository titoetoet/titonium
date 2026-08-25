pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root
    readonly property var clockState: ConfigStore.previewState.modules?.clock || ({})

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Controls.TextLabel { text: I18n.tr("settings.system.title"); variant: "title_large"; strong: true }
        Controls.TextLabel {
            text: I18n.tr("settings.system.description")
            variant: "body"; tone: "secondary"; wrapMode: Text.WordWrap; Layout.fillWidth: true
        }

        Controls.TextLabel { text: I18n.tr("settings.system.language"); strong: true }
        Controls.Tabs {
            model: [
                { "label": "Tiếng Việt", "value": "vi" },
                { "label": "English", "value": "en" }
            ]
            currentIndex: ConfigStore.previewState.locale === "en" ? 1 : 0
            accessibleName: I18n.tr("settings.system.language")
            onActivated: (index, value) => ConfigStore.patch("locale", value)
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: Metrics.borderWidth; color: Theme.border }

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Controls.TextLabel { text: I18n.tr("settings.system.clock_24h"); strong: true }
                Controls.TextLabel { text: I18n.tr("settings.system.clock_24h_description"); variant: "caption"; tone: "secondary" }
            }
            Controls.Switch {
                checked: root.clockState.use24Hour !== false
                accessibleName: I18n.tr("settings.system.clock_24h")
                onToggled: checked => ConfigStore.patch("modules.clock.use24Hour", checked)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Controls.TextLabel { text: I18n.tr("settings.system.lunar"); strong: true }
                Controls.TextLabel { text: I18n.tr("settings.system.lunar_description"); variant: "caption"; tone: "secondary" }
            }
            Controls.Switch {
                checked: root.clockState.showLunar !== false
                accessibleName: I18n.tr("settings.system.lunar")
                onToggled: checked => ConfigStore.patch("modules.clock.showLunar", checked)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Controls.TextLabel { text: I18n.tr("settings.system.reduced_motion"); strong: true }
                Controls.TextLabel { text: I18n.tr("settings.system.reduced_motion_description"); variant: "caption"; tone: "secondary" }
            }
            Controls.Switch {
                checked: ConfigStore.previewState.accessibility?.reducedMotion === true
                accessibleName: I18n.tr("settings.system.reduced_motion")
                onToggled: checked => ConfigStore.patch("accessibility.reducedMotion", checked)
            }
        }

        Controls.Surface {
            Layout.fillWidth: true
            implicitWidth: 1; implicitHeight: 72
            tone: "elevated"; radius: Metrics.radiusMedium; outlined: true
            RowLayout {
                anchors.fill: parent; anchors.margins: Metrics.spacingMedium
                Controls.Icon { name: "shield"; tone: "accent"; accessibleName: "" }
                Controls.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("settings.system.no_actions")
                    variant: "caption"; tone: "secondary"; wrapMode: Text.WordWrap
                }
            }
        }

        Controls.Button {
            label: I18n.tr("settings.system.reset")
            iconName: "restart_alt"; variant: "secondary"
            onTriggered: {
                ConfigStore.patch("locale", ConfigStore.shippedDefaults.locale);
                ConfigStore.patch("accessibility", ConfigStore.shippedDefaults.accessibility);
                ConfigStore.patch("modules.clock", ConfigStore.shippedDefaults.modules.clock);
            }
        }
        Item { Layout.fillHeight: true }
    }
}
