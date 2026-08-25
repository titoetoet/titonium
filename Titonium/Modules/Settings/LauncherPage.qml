pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root
    readonly property var launcherState: ConfigStore.previewState.modules?.launcher || ({})
    readonly property var categories: [
        { "label": I18n.tr("launcher.category.all"), "value": "all" },
        { "label": I18n.tr("launcher.category.internet"), "value": "internet" },
        { "label": I18n.tr("launcher.category.development"), "value": "development" },
        { "label": I18n.tr("launcher.category.media"), "value": "media" },
        { "label": I18n.tr("launcher.category.system"), "value": "system" }
    ]

    function categoryIndex(): int {
        for (let index = 0; index < root.categories.length; index++)
            if (root.categories[index].value === root.launcherState.defaultCategory) return index;
        return 0;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingLarge

        Controls.TextLabel { text: I18n.tr("settings.launcher.title"); variant: "title_large"; strong: true }
        Controls.TextLabel {
            text: I18n.tr("settings.launcher.description")
            variant: "body"; tone: "secondary"; wrapMode: Text.WordWrap; Layout.fillWidth: true
        }

        Controls.TextLabel { text: I18n.tr("settings.launcher.default_category"); strong: true }
        Controls.Dropdown {
            Layout.fillWidth: true
            model: root.categories
            currentIndex: root.categoryIndex()
            accessibleName: I18n.tr("settings.launcher.default_category")
            onSelected: (index, value) => ConfigStore.patch("modules.launcher.defaultCategory", value)
        }

        RowLayout {
            Layout.fillWidth: true
            Controls.TextLabel { text: I18n.tr("settings.launcher.result_limit"); strong: true }
            Item { Layout.fillWidth: true }
            Controls.TextLabel { text: String(root.launcherState.resultLimit || 24); variant: "mono"; tone: "accent" }
        }
        Controls.Slider {
            Layout.fillWidth: true
            from: 6; to: 48; stepSize: 6
            value: root.launcherState.resultLimit || 24
            accessibleName: I18n.tr("settings.launcher.result_limit")
            onMoved: value => ConfigStore.patch("modules.launcher.resultLimit", Math.round(value))
        }

        RowLayout {
            Layout.fillWidth: true
            Controls.TextLabel { text: I18n.tr("settings.launcher.columns"); strong: true }
            Item { Layout.fillWidth: true }
            Controls.TextLabel { text: String(root.launcherState.columns || 6); variant: "mono"; tone: "accent" }
        }
        Controls.Slider {
            Layout.fillWidth: true
            from: 4; to: 8; stepSize: 1
            value: root.launcherState.columns || 6
            accessibleName: I18n.tr("settings.launcher.columns")
            onMoved: value => ConfigStore.patch("modules.launcher.columns", Math.round(value))
        }

        RowLayout {
            Layout.fillWidth: true
            Controls.TextLabel { Layout.fillWidth: true; text: I18n.tr("settings.launcher.show_subtitles"); strong: true }
            Controls.Switch {
                checked: root.launcherState.showSubtitles !== false
                accessibleName: I18n.tr("settings.launcher.show_subtitles")
                onToggled: checked => ConfigStore.patch("modules.launcher.showSubtitles", checked)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Controls.TextLabel { Layout.fillWidth: true; text: I18n.tr("settings.launcher.autofocus"); strong: true }
            Controls.Switch {
                checked: root.launcherState.searchAutoFocus !== false
                accessibleName: I18n.tr("settings.launcher.autofocus")
                onToggled: checked => ConfigStore.patch("modules.launcher.searchAutoFocus", checked)
            }
        }

        Controls.Button {
            label: I18n.tr("settings.launcher.reset")
            iconName: "restart_alt"; variant: "secondary"
            onTriggered: ConfigStore.patch("modules.launcher", ConfigStore.shippedDefaults.modules.launcher)
        }
        Item { Layout.fillHeight: true }
    }
}
