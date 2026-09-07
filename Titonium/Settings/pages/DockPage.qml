pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Dock
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.components

Item {
    id: root

    readonly property var styleOptions: Object.freeze([
        Object.freeze({ value: "follow-topbar", label: I18n.tr("settings.dock.style.follow_topbar") }),
        Object.freeze({ value: "connected", label: I18n.tr("settings.bar.style.connected") }),
        Object.freeze({ value: "classic", label: I18n.tr("settings.bar.style.classic") }),
    ])

    readonly property var modes: Object.freeze([
        Object.freeze({ value: "auto-hide", icon: "visibility_off",
            labelKey: "settings.dock.mode.auto_hide" }),
        Object.freeze({ value: "always-visible", icon: "visibility",
            labelKey: "settings.dock.mode.always_visible" }),
        Object.freeze({ value: "reserve-space", icon: "select_window_2",
            labelKey: "settings.dock.mode.reserve_space" }),
        Object.freeze({ value: "hidden", icon: "visibility_off",
            labelKey: "settings.dock.mode.hidden" }),
    ])

    Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: Controls.ScrollBar {}

        ColumnLayout {
            id: content
            width: scroll.width - 12
            spacing: Metrics.spacingMedium

            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.dock.description")
                tone: "secondary"
                wrapMode: Text.WordWrap
            }

            SettingRow {
                Layout.fillWidth: true
                title: I18n.tr("settings.dock.style")
                description: I18n.tr("settings.dock.style.description")

                Shared.Select {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    model: root.styleOptions
                    currentIndex: Math.max(0, root.styleOptions.findIndex(
                        option => option.value === Preferences.dock.style))
                    accessibleName: I18n.tr("settings.dock.style")
                    onSelected: (index, value) => Preferences.patch("modules.dock.style", value)
                }
            }

            Shared.TextLabel {
                text: I18n.tr("settings.dock.mode")
                variant: "label"
                strong: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 800 ? 2 : 4
                columnSpacing: Metrics.spacingSmall
                rowSpacing: Metrics.spacingSmall

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
                Layout.preferredHeight: 380
            }
        }
    }
}
