pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation
import qs.Titonium.Platform.System

Item {
    id: root

    readonly property var launcherState: ConfigStore.previewState.modules?.launcher || ({})
    readonly property var avatarIcons: [
        "person", "terminal", "face", "smart_toy", "rocket_launch", "sports_esports",
        "bolt", "coffee", "palette", "pets", "headphones", "local_fire_department",
        "code", "music_note", "public", "diamond"
    ]
    function transitionIndex(): int {
        const values = ["slide-fade", "slide", "slide-scale", "none"];
        const index = values.indexOf(root.launcherState.pageTransition);
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

            Controls.TextLabel { text: I18n.tr("settings.launcher.title"); variant: "title_large"; strong: true }
            Controls.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.launcher.description")
                variant: "body"; tone: "secondary"; wrapMode: Text.WordWrap
            }

            Controls.TextLabel { text: I18n.tr("settings.launcher.username"); strong: true }
            Controls.Surface {
                Layout.fillWidth: true
                implicitWidth: 1
                implicitHeight: 40
                tone: "elevated"
                radius: Metrics.radiusMedium
                outlined: true
                borderColor: usernameInput.activeFocus ? Theme.focus : Theme.border

                TextInput {
                    id: usernameInput
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.spacingMedium
                    anchors.rightMargin: Metrics.spacingMedium
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.launcherState.username || ""
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    font.family: Typography.family
                    font.pixelSize: Typography.sizeFor("body")
                    maximumLength: 40
                    selectByMouse: true
                    onTextEdited: ConfigStore.patch("modules.launcher.username", text)

                    Controls.TextLabel {
                        anchors.fill: parent
                        visible: usernameInput.text.length === 0
                        text: I18n.tr("settings.launcher.username_placeholder", { "name": UserIdentity.loginName })
                        tone: "secondary"
                    }
                }
            }

            Controls.TextLabel { text: I18n.tr("settings.launcher.avatar"); strong: true }
            GridLayout {
                Layout.fillWidth: true
                columns: 8
                rowSpacing: Metrics.spacingSmall
                columnSpacing: Metrics.spacingSmall

                Repeater {
                    model: root.avatarIcons
                    Controls.Button {
                        required property string modelData
                        Layout.fillWidth: true
                        implicitHeight: 48
                        iconName: modelData
                        variant: "quiet"
                        selected: root.launcherState.avatarIcon === modelData
                        accessibleName: I18n.tr("settings.launcher.avatar_choice", { "icon": modelData })
                        onTriggered: ConfigStore.patch("modules.launcher.avatarIcon", modelData)
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: Metrics.borderWidth; color: Theme.border }

            RowLayout {
                Layout.fillWidth: true
                Controls.TextLabel { text: I18n.tr("settings.launcher.grid"); strong: true }
                Item { Layout.fillWidth: true }
                Controls.TextLabel { text: I18n.tr("settings.launcher.grid_adaptive"); variant: "caption"; tone: "accent" }
            }
            Controls.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.launcher.grid_description")
                variant: "caption"; tone: "secondary"; wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingLarge

                ColumnLayout {
                    Layout.fillWidth: true
                    Controls.TextLabel { text: I18n.tr("settings.launcher.transition"); strong: true }
                    Controls.Dropdown {
                        Layout.fillWidth: true
                        model: [
                            { "label": I18n.tr("settings.launcher.transition.slide_fade"), "value": "slide-fade" },
                            { "label": I18n.tr("settings.launcher.transition.slide"), "value": "slide" },
                            { "label": I18n.tr("settings.launcher.transition.slide_scale"), "value": "slide-scale" },
                            { "label": I18n.tr("settings.launcher.transition.none"), "value": "none" }
                        ]
                        currentIndex: root.transitionIndex()
                        accessibleName: I18n.tr("settings.launcher.transition")
                        onSelected: (index, value) => ConfigStore.patch("modules.launcher.pageTransition", value)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        Controls.TextLabel { text: I18n.tr("settings.launcher.transition_duration"); strong: true }
                        Item { Layout.fillWidth: true }
                        Controls.TextLabel {
                            text: (root.launcherState.transitionDuration || 220) + " ms"
                            variant: "mono"; tone: "accent"
                        }
                    }
                    Controls.Slider {
                        Layout.fillWidth: true
                        from: 80; to: 500; stepSize: 20
                        value: root.launcherState.transitionDuration || 220
                        enabled: root.launcherState.pageTransition !== "none"
                        accessibleName: I18n.tr("settings.launcher.transition_duration")
                        onMoved: value => ConfigStore.patch("modules.launcher.transitionDuration", Math.round(value))
                    }
                }
            }

            Controls.Button {
                label: I18n.tr("settings.launcher.reset")
                iconName: "restart_alt"
                variant: "secondary"
                onTriggered: ConfigStore.patch("modules.launcher", ConfigStore.shippedDefaults.modules.launcher)
            }
        }
    }
}
