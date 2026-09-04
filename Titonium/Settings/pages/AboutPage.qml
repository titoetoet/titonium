pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Screens
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Bluetooth
import qs.Titonium.Services.Network
import qs.Titonium.Services.Notifications
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root

    function stateText(available: bool): string {
        return I18n.tr(available ? "settings.state.ready" : "settings.state.unavailable");
    }

    readonly property var diagnostics: [
        { label: I18n.tr("settings.about.schema"),
            value: Preferences.effectiveState.$schema || "titonium.settings/v7" },
        { label: I18n.tr("settings.about.screen"), value: ScreenPolicy.targetScreenName },
        { label: I18n.tr("settings.about.runtime"), value: Preferences.runtimePath },
        { label: I18n.tr("settings.about.applications"),
            value: String(ApplicationService.allApplications.length) },
        { label: I18n.tr("settings.about.audio"), value: root.stateText(AudioService.ready) },
        { label: I18n.tr("settings.about.network"), value: root.stateText(NetworkService.available) },
        { label: I18n.tr("settings.about.bluetooth"), value: root.stateText(BluetoothService.available) },
        { label: I18n.tr("settings.about.notifications"),
            value: NotificationCoordinator.history.length + " · "
                + NotificationCoordinator.unreadCount },
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.about.title")
            variant: "titleLarge"
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            text: I18n.tr("settings.about.description")
            tone: "secondary"
            wrapMode: Text.WordWrap
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.diagnostics
            currentIndex: -1
            clip: true
            spacing: Metrics.spacingXSmall
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true

            delegate: Rectangle {
                id: diagnosticRow
                required property var modelData

                width: ListView.view.width
                height: 48
                radius: Metrics.radiusMedium
                color: Theme.surfaceElevated

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Metrics.spacingMedium
                    anchors.rightMargin: Metrics.spacingMedium
                    spacing: Metrics.spacingLarge

                    Shared.TextLabel {
                        Layout.preferredWidth: 180
                        text: diagnosticRow.modelData.label
                        variant: "label"
                        strong: true
                    }

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: diagnosticRow.modelData.value
                        tone: "secondary"
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }
}
