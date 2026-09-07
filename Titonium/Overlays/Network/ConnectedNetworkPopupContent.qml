pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Network
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    readonly property real implicitContentWidth: 380
    readonly property real implicitContentHeight: contentColumn.implicitHeight + 32
    implicitWidth: implicitContentWidth
    implicitHeight: implicitContentHeight

    signal dismissRequested()

    function networksFor(section: string): var {
        return NetworkService.networks.filter(network => network.section === section);
    }

    Flickable {
        id: contentFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: root.implicitContentHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            x: 16
            y: 16
            width: Math.max(0, contentFlickable.width - 32)
            spacing: Metrics.spacingMedium

            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacingMedium

                Shared.Icon {
                    name: NetworkService.iconName
                    size: 24
                    tone: NetworkService.wifiEnabled ? "accent" : "disabled"
                    accessibleName: ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXSmall

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: I18n.tr("wifi.title")
                        variant: "title"
                        strong: true
                    }

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: I18n.tr(NetworkService.stateKey, { "name": NetworkService.connectedName })
                        tone: "secondary"
                        variant: "caption"
                        elide: Text.ElideRight
                    }
                }

                Shared.Button {
                    iconName: NetworkService.scanning ? "sync" : "refresh"
                    variant: "quiet"
                    size: "small"
                    enabled: NetworkService.available && NetworkService.wifiEnabled
                    accessibleName: I18n.tr(NetworkService.scanning
                        ? "wifi.scan.stop.accessible" : "wifi.scan.start.accessible")
                    onTriggered: NetworkService.setScanning(!NetworkService.scanning)
                }

                Shared.Button {
                    iconName: NetworkService.wifiEnabled ? "wifi_off" : "wifi"
                    variant: "quiet"
                    size: "small"
                    enabled: NetworkService.available && NetworkService.wifiHardwareEnabled
                    accessibleName: I18n.tr(NetworkService.wifiEnabled
                        ? "wifi.power.off.accessible" : "wifi.power.on.accessible")
                    onTriggered: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.borderWidth
                color: Theme.border
            }

            Repeater {
                model: ["connected", "known", "available"]

                delegate: ColumnLayout {
                    id: section
                    required property string modelData
                    readonly property var sectionNetworks: root.networksFor(modelData)
                    readonly property string sectionTitle: I18n.tr("wifi.section." + section.modelData)

                    Layout.fillWidth: true
                    spacing: Metrics.spacingSmall
                    visible: NetworkService.wifiEnabled && sectionNetworks.length > 0

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: section.sectionTitle
                        variant: "label"
                        strong: true
                        Accessible.role: Accessible.Heading
                        Accessible.name: section.sectionTitle
                    }

                    Repeater {
                        model: WifiNetworkModel {
                            networks: section.sectionNetworks
                        }

                        delegate: WifiNetworkRow {
                            required property var descriptor
                            Layout.fillWidth: true
                            network: descriptor
                        }
                    }
                }
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: NetworkService.wifiEnabled && NetworkService.networks.length === 0
                text: I18n.tr(NetworkService.scanning ? "wifi.networks.scanning" : "wifi.networks.empty")
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: !NetworkService.available || !NetworkService.wifiHardwareEnabled
                text: I18n.tr(!NetworkService.available ? "wifi.unavailable" : "wifi.hardware_off")
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
