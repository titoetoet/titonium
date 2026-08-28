pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.components

Item {
    id: root

    readonly property var spotlightState: Preferences.spotlight
    readonly property int duration: Number(root.spotlightState.transitionDuration ?? 220)
    readonly property var transitionOptions: Object.freeze([
        Object.freeze({ label: I18n.tr("settings.spotlight.transition.slide_fade"), value: "slide-fade" }),
        Object.freeze({ label: I18n.tr("settings.spotlight.transition.fade"), value: "fade" }),
        Object.freeze({ label: I18n.tr("settings.spotlight.transition.none"), value: "none" }),
    ])

    function transitionIndex(): int {
        const value = root.spotlightState.pageTransition || "slide-fade";
        return ["slide-fade", "fade", "none"].indexOf(value);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.spotlight.title")
            variant: "titleLarge"
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.spotlight.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingLarge

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                Shared.TextLabel {
                    text: I18n.tr("settings.spotlight.transition")
                    variant: "label"
                    strong: true
                }

                Shared.Select {
                    Layout.fillWidth: true
                    model: root.transitionOptions
                    currentIndex: Math.max(0, root.transitionIndex())
                    accessibleName: I18n.tr("settings.spotlight.transition")
                    onSelected: (index, value) => Preferences.patch("modules.spotlight.pageTransition", value)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingSmall

                Shared.TextLabel {
                    text: I18n.tr("settings.spotlight.duration", { "value": root.duration })
                    variant: "label"
                    strong: true
                }

                Shared.Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 500
                    stepSize: 20
                    value: root.duration
                    enabled: root.spotlightState.pageTransition !== "none"
                    accessibleName: I18n.tr("settings.spotlight.duration", { "value": root.duration })
                    onMoved: value => Preferences.patch("modules.spotlight.transitionDuration",
                        Math.round(value))
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.borderWidth
            color: Theme.border
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.spotlight.hidden_count", {
                "count": Preferences.hiddenApplicationIds.length
            })
            variant: "titleSmall"
            strong: true
        }

        ApplicationVisibilityList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
