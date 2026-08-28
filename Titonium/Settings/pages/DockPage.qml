pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Dock
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.components

Item {
    id: root

    readonly property var modes: Object.freeze([
        Object.freeze({ value: "auto-hide", icon: "visibility_off",
            labelKey: "settings.dock.mode.auto_hide" }),
        Object.freeze({ value: "always-visible", icon: "visibility",
            labelKey: "settings.dock.mode.always_visible" }),
        Object.freeze({ value: "reserve-space", icon: "select_window_2",
            labelKey: "settings.dock.mode.reserve_space" }),
    ])

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.dock.title")
            variant: "titleLarge"
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.dock.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        Shared.TextLabel {
            text: I18n.tr("settings.dock.mode")
            variant: "label"
            strong: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall

            Repeater {
                model: root.modes

                Shared.Button {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    label: I18n.tr(modelData.labelKey)
                    iconName: modelData.icon
                    selected: DockStore.visibilityMode === modelData.value
                    onTriggered: DockStore.setVisibilityMode(modelData.value)
                }
            }
        }

        DockApplicationEditor {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
