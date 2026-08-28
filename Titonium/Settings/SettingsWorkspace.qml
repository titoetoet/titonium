pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared
import qs.Titonium.Settings.pages
import "SettingsCatalog.js" as SettingsCatalog

Item {
    id: root

    readonly property var navigationEntries: SettingsCatalog.navigationEntries()

    function componentFor(pageId: string): Component {
        if (pageId === "appearance")
            return appearancePage;
        if (pageId === "spotlight")
            return spotlightPage;
        if (pageId === "bar")
            return barPage;
        if (pageId === "dock")
            return dockPage;
        return generalPage;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Metrics.spacingLarge
                anchors.rightMargin: Metrics.spacingMedium
                spacing: Metrics.spacingMedium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Shared.TextLabel {
                        text: I18n.tr("settings.title")
                        variant: "title"
                        strong: true
                    }

                    Shared.TextLabel {
                        text: I18n.tr("settings.preview_hint")
                        variant: "bodySmall"
                        tone: "secondary"
                    }
                }

                Shared.Button {
                    iconName: "close"
                    variant: "quiet"
                    accessibleName: I18n.tr("settings.close")
                    enabled: !Preferences.savePending
                    onTriggered: SettingsCoordinator.requestClose()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.borderWidth
            color: Theme.border
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.preferredWidth: 208
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Metrics.spacingMedium
                    spacing: Metrics.spacingSmall

                    Repeater {
                        model: root.navigationEntries

                        Shared.Button {
                            required property var modelData
                            Layout.fillWidth: true
                            label: I18n.tr(modelData.labelKey)
                            iconName: modelData.icon
                            variant: "quiet"
                            selected: SettingsCoordinator.requestedPage === modelData.id
                            contentAlignment: Qt.AlignLeft
                            accessibleName: label
                            onTriggered: SettingsCoordinator.requestPage(modelData.id)
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: Metrics.borderWidth
                color: Theme.border
            }

            Loader {
                id: pageLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 24
                active: SettingsCoordinator.active
                sourceComponent: root.componentFor(SettingsCoordinator.requestedPage)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Metrics.borderWidth
            color: Theme.border
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 64

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Metrics.spacingLarge
                anchors.rightMargin: Metrics.spacingLarge
                spacing: Metrics.spacingSmall

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: Preferences.lastError.length > 0 ? Preferences.lastError
                        : (Preferences.savePending ? I18n.tr("settings.saving")
                            : (Preferences.dirty ? I18n.tr("settings.unsaved") : ""))
                    tone: Preferences.lastError.length > 0 ? "danger" : "secondary"
                    elide: Text.ElideRight
                }

                Shared.Button {
                    label: I18n.tr("settings.cancel")
                    enabled: !Preferences.savePending
                    onTriggered: SettingsCoordinator.discardAndClose()
                }

                Shared.Button {
                    label: Preferences.savePending ? I18n.tr("settings.saving")
                        : I18n.tr("settings.apply")
                    variant: "primary"
                    enabled: Preferences.dirty && !Preferences.savePending
                    onTriggered: SettingsCoordinator.apply()
                }
            }
        }
    }

    Component {
        id: generalPage
        GeneralPage {}
    }

    Component {
        id: appearancePage
        AppearancePage {}
    }

    Component {
        id: spotlightPage
        SpotlightPage {}
    }

    Component {
        id: barPage
        BarPage {}
    }

    Component {
        id: dockPage
        DockPage {}
    }

    Rectangle {
        anchors.fill: parent
        visible: SettingsCoordinator.discardConfirmationVisible
        color: Theme.background
        radius: Metrics.radiusLarge
        z: 10

        MouseArea { anchors.fill: parent }

        Shared.Panel {
            anchors.centerIn: parent
            width: 460
            height: confirmationContent.implicitHeight + Metrics.spacingLarge * 2

            ColumnLayout {
                id: confirmationContent
                anchors.fill: parent
                spacing: Metrics.spacingMedium

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("settings.discard.title")
                    variant: "title"
                    strong: true
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("settings.discard.body")
                    tone: "secondary"
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Metrics.spacingSmall

                    Shared.Button {
                        label: I18n.tr("settings.discard.continue")
                        onTriggered: SettingsCoordinator.discardConfirmationVisible = false
                    }

                    Shared.Button {
                        label: I18n.tr("settings.discard.confirm")
                        variant: "danger"
                        onTriggered: SettingsCoordinator.discardAndClose()
                    }
                }
            }
        }
    }
}
