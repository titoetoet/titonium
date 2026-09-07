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
    readonly property var primaryNavigationEntries:
        root.navigationEntries.filter(entry => entry.id !== "about")
    readonly property var aboutNavigationEntry:
        root.navigationEntries.find(entry => entry.id === "about")

    function componentFor(pageId: string): Component {
        if (pageId === "appearance")
            return appearancePage;
        if (pageId === "spotlight")
            return spotlightPage;
        if (pageId === "bar")
            return barPage;
        if (pageId === "dock")
            return dockPage;
        if (pageId === "notifications")
            return notificationsPage;
        if (pageId === "audio")
            return audioPage;
        if (pageId === "about")
            return aboutPage;
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
                anchors.rightMargin: 52
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
                        model: root.primaryNavigationEntries

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

                    Shared.Button {
                        Layout.fillWidth: true
                        label: I18n.tr(root.aboutNavigationEntry.labelKey)
                        iconName: root.aboutNavigationEntry.icon
                        variant: "quiet"
                        selected: SettingsCoordinator.requestedPage
                            === root.aboutNavigationEntry.id
                        contentAlignment: Qt.AlignLeft
                        accessibleName: label
                        onTriggered: SettingsCoordinator.requestPage(
                            root.aboutNavigationEntry.id)
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: Metrics.borderWidth
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 24
                spacing: Metrics.spacingSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingMedium

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: I18n.tr("settings." + SettingsCoordinator.requestedPage + ".title")
                        variant: "titleLarge"
                        elide: Text.ElideRight
                    }

                    Shared.Button {
                        visible: SettingsCoordinator.requestedPage !== "about"
                        iconName: "restart_alt"
                        label: I18n.tr("settings.reset.page")
                        size: "small"
                        variant: "quiet"
                        enabled: !SettingsCoordinator.busy && AppearanceCoordinator.editable()
                        onTriggered: SettingsCoordinator.restoreDefaults(false)
                    }
                }

                Loader {
                    id: pageLoader
                    objectName: "settingsPageLoader"
                    enabled: !SettingsCoordinator.busy
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    active: SettingsCoordinator.active
                    sourceComponent: root.componentFor(SettingsCoordinator.requestedPage)
                }
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

                Shared.Button {
                    label: I18n.tr("settings.reset.all")
                    iconName: "restart_alt"
                    variant: "quiet"
                    enabled: !SettingsCoordinator.busy && AppearanceCoordinator.editable()
                    onTriggered: SettingsCoordinator.restoreDefaults(true)
                }

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: AppearanceCoordinator.error ? I18n.tr(AppearanceCoordinator.error)
                        : Preferences.lastError.length > 0 ? Preferences.lastError
                        : (SettingsCoordinator.busy ? I18n.tr("settings.saving")
                            : (SettingsCoordinator.dirty ? I18n.tr("settings.unsaved") : ""))
                    tone: AppearanceCoordinator.error || Preferences.lastError.length > 0 ? "danger" : "secondary"
                    elide: Text.ElideRight
                }

                Shared.Button {
                    label: SettingsCoordinator.busy ? I18n.tr("settings.saving")
                        : I18n.tr("settings.apply")
                    variant: "primary"
                    enabled: SettingsCoordinator.dirty && !SettingsCoordinator.busy && !AppearanceCoordinator.trialActive
                        && !AppearanceCoordinator.themeWallpaperMissing
                    onTriggered: SettingsCoordinator.apply()
                }
            }
        }
    }

    Shared.Button {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 6
        iconName: "close"
        size: "small"
        variant: "quiet"
        accessibleName: I18n.tr("settings.close")
        enabled: !SettingsCoordinator.busy
        onTriggered: SettingsCoordinator.requestClose()
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

    Component {
        id: notificationsPage
        NotificationsPage {}
    }

    Component {
        id: audioPage
        AudioPage {}
    }

    Component {
        id: aboutPage
        AboutPage {}
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
