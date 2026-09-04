pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.components
import "../NotificationSettingsRules.js" as NotificationSettingsRules

Item {
    id: root

    readonly property bool toastsEnabled: Preferences.notifications.toastsEnabled !== false
    readonly property int toastDuration: Preferences.notifications.toastDuration || 5000
    readonly property string policyMode: Preferences.notifications.policyMode === "custom"
        ? "custom" : "automatic"
    readonly property var applicationOverrides:
        Preferences.notifications.applicationOverrides || ({})
    readonly property var applicationRows: NotificationSettingsRules.applicationRows(
        ApplicationService.allApplications, root.applicationOverrides)
    readonly property var overrideOptions: Object.freeze([
        Object.freeze({ value: "follow",
            label: I18n.tr("settings.notifications.override.follow") }),
        Object.freeze({ value: "quiet",
            label: I18n.tr("settings.notifications.override.quiet") }),
        Object.freeze({ value: "normal",
            label: I18n.tr("settings.notifications.override.normal") }),
        Object.freeze({ value: "critical",
            label: I18n.tr("settings.notifications.override.critical") }),
        Object.freeze({ value: "block",
            label: I18n.tr("settings.notifications.override.block") }),
    ])

    function overrideIndex(appId: string): int {
        const current = NotificationSettingsRules.currentOverride(
            root.applicationOverrides, appId);
        return root.overrideOptions.findIndex(option => option.value === current);
    }

    function patchOverrides(next: var): void {
        Preferences.patch("modules.notifications.applicationOverrides", next);
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: Metrics.spacingMedium

            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.notifications.title")
                variant: "titleLarge"
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("settings.notifications.description")
                tone: "secondary"
                wrapMode: Text.WordWrap
            }

            SettingRow {
                Layout.fillWidth: true
                title: I18n.tr("settings.notifications.policy_mode")
                description: I18n.tr("settings.notifications.policy_mode.description")

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Metrics.spacingSmall

                    Shared.Button {
                        label: I18n.tr("settings.notifications.policy.automatic")
                        selected: root.policyMode === "automatic"
                        onTriggered: Preferences.patch("modules.notifications.policyMode",
                            "automatic")
                    }

                    Shared.Button {
                        label: I18n.tr("settings.notifications.policy.custom")
                        selected: root.policyMode === "custom"
                        onTriggered: Preferences.patch("modules.notifications.policyMode",
                            "custom")
                    }
                }
            }

            SettingRow {
                Layout.fillWidth: true
                title: I18n.tr("settings.notifications.toasts")

                Shared.Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.toastsEnabled
                    accessibleName: I18n.tr("settings.notifications.toasts")
                    onToggled: checked => Preferences.patch("modules.notifications.toastsEnabled",
                        checked)
                }
            }

            SettingRow {
                Layout.fillWidth: true
                title: I18n.tr("settings.notifications.duration", {
                    "seconds": (root.toastDuration / 1000).toFixed(1)
                })

                Shared.Slider {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    from: 2000
                    to: 10000
                    stepSize: 500
                    value: root.toastDuration
                    enabled: root.toastsEnabled
                    accessibleName: I18n.tr("settings.notifications.duration", {
                        "seconds": (root.toastDuration / 1000).toFixed(1)
                    })
                    onMoved: value => Preferences.patch("modules.notifications.toastDuration",
                        Math.round(value))
                }
            }

            SettingRow {
                Layout.fillWidth: true
                title: I18n.tr("settings.notifications.allow_critical_on_island")
                description: I18n.tr(
                    "settings.notifications.allow_critical_on_island.description")

                Shared.Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Preferences.notifications.allowCriticalOnIsland !== false
                    accessibleName: I18n.tr(
                        "settings.notifications.allow_critical_on_island")
                    onToggled: checked => Preferences.patch("modules.notifications.allowCriticalOnIsland",
                        checked)
                }
            }

            SettingRow {
                Layout.fillWidth: true
                title: I18n.tr("settings.notifications.keep_critical_unread")
                description: I18n.tr(
                    "settings.notifications.keep_critical_unread.description")

                Shared.Toggle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Preferences.notifications.keepCriticalUnread !== false
                    accessibleName: I18n.tr(
                        "settings.notifications.keep_critical_unread")
                    onToggled: checked => Preferences.patch("modules.notifications.keepCriticalUnread",
                        checked)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.borderWidth
                color: Theme.border
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingMedium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXSmall

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: I18n.tr("settings.notifications.overrides")
                        variant: "titleSmall"
                        strong: true
                    }

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: I18n.tr("settings.notifications.overrides.description")
                        tone: "secondary"
                        variant: "bodySmall"
                        wrapMode: Text.WordWrap
                    }
                }

                Shared.Button {
                    label: I18n.tr("settings.notifications.overrides.reset_all")
                    iconName: "restart_alt"
                    size: "small"
                    enabled: root.policyMode === "custom"
                        && Object.keys(root.applicationOverrides).length > 0
                    onTriggered: root.patchOverrides(NotificationSettingsRules.resetAll())
                }
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                visible: root.policyMode !== "custom"
                text: I18n.tr("settings.notifications.overrides.automatic_hint")
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                visible: root.policyMode === "custom"

                ListView {
                    id: overrideList
                    anchors.fill: parent
                    model: root.applicationRows
                    clip: true
                    spacing: Metrics.spacingXSmall
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true

                    delegate: Shared.Surface {
                        id: applicationRow
                        required property var modelData

                        width: overrideList.width
                        implicitHeight: 58
                        tone: "elevated"
                        radius: Metrics.radiusMedium

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Metrics.spacingMedium
                            anchors.rightMargin: Metrics.spacingSmall
                            spacing: Metrics.spacingMedium

                            Shared.SystemIcon {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                sourceName: applicationRow.modelData.icon || ""
                                fallbackName: "apps"
                                size: 30
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Shared.TextLabel {
                                    Layout.fillWidth: true
                                    text: applicationRow.modelData.name
                                    variant: "label"
                                    strong: true
                                    elide: Text.ElideRight
                                }

                                Shared.TextLabel {
                                    Layout.fillWidth: true
                                    text: applicationRow.modelData.id
                                    visible: applicationRow.modelData.id
                                        !== applicationRow.modelData.name
                                    variant: "caption"
                                    tone: "secondary"
                                    elide: Text.ElideRight
                                }
                            }

                            Shared.Select {
                                Layout.preferredWidth: 150
                                model: root.overrideOptions
                                currentIndex: root.overrideIndex(applicationRow.modelData.id)
                                accessibleName: I18n.tr(
                                    "settings.notifications.override.accessible", {
                                        "name": applicationRow.modelData.name
                                    })
                                onSelected: (index, value) => root.patchOverrides(
                                    NotificationSettingsRules.setOverride(
                                        root.applicationOverrides,
                                        applicationRow.modelData.id, value))
                            }

                            Shared.Button {
                                iconName: "restart_alt"
                                size: "small"
                                variant: "quiet"
                                enabled: NotificationSettingsRules.currentOverride(
                                    root.applicationOverrides,
                                    applicationRow.modelData.id) !== "follow"
                                accessibleName: I18n.tr(
                                    "settings.notifications.override.reset", {
                                        "name": applicationRow.modelData.name
                                    })
                                onTriggered: root.patchOverrides(
                                    NotificationSettingsRules.resetOverride(
                                        root.applicationOverrides,
                                        applicationRow.modelData.id))
                            }
                        }
                    }
                }

                Shared.TextLabel {
                    anchors.centerIn: parent
                    visible: root.applicationRows.length === 0
                    text: I18n.tr("settings.notifications.overrides.empty")
                    tone: "secondary"
                }
            }
        }
    }
}
