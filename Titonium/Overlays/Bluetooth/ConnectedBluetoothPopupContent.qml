pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Bluetooth
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    readonly property real implicitContentWidth: 380
    readonly property real implicitContentHeight: contentColumn.implicitHeight + 32
    implicitWidth: implicitContentWidth
    implicitHeight: implicitContentHeight

    signal dismissRequested()

    function devicesFor(section: string): var {
        return BluetoothService.devices.filter(device => device.section === section);
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
                    name: BluetoothService.powered ? "bluetooth" : "bluetooth_disabled"
                    size: 24
                    tone: BluetoothService.powered ? "accent" : "disabled"
                    accessibleName: ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXSmall

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: BluetoothService.adapterName || I18n.tr("bluetooth.title")
                        variant: "title"
                        strong: true
                        elide: Text.ElideRight
                    }

                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: I18n.tr(BluetoothService.stateKey, {
                            "count": BluetoothService.connectedCount
                        })
                        tone: "secondary"
                        variant: "caption"
                        elide: Text.ElideRight
                    }
                }

                Shared.Button {
                    iconName: BluetoothService.powered ? "bluetooth_disabled" : "bluetooth"
                    variant: "quiet"
                    size: "small"
                    enabled: BluetoothService.available
                    accessibleName: I18n.tr(BluetoothService.powered
                        ? "bluetooth.power.off.accessible" : "bluetooth.power.on.accessible")
                    onTriggered: BluetoothService.setPowered(!BluetoothService.powered)
                }

                Shared.Button {
                    iconName: "sync"
                    iconSpinning: BluetoothService.discovering
                    variant: "quiet"
                    size: "small"
                    selected: BluetoothService.discovering
                    enabled: BluetoothService.powered
                    accessibleName: I18n.tr(BluetoothService.discovering
                        ? "bluetooth.scan.stop.accessible" : "bluetooth.scan.start.accessible")
                    onTriggered: BluetoothService.setDiscovering(!BluetoothService.discovering)
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.borderWidth
                color: Theme.border
            }

            Repeater {
                model: ["connected", "paired", "available"]

                delegate: ColumnLayout {
                    id: section
                    required property string modelData
                    readonly property var sectionDevices: root.devicesFor(modelData)
                    readonly property string sectionTitle: I18n.tr(
                        "bluetooth.section." + section.modelData, {
                            "count": section.sectionDevices.length
                        })

                    Layout.fillWidth: true
                    spacing: Metrics.spacingSmall
                    visible: sectionDevices.length > 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingSmall

                        Shared.Icon {
                            name: section.modelData === "connected" ? "link"
                                : (section.modelData === "paired" ? "devices" : "radar")
                            size: 18
                            tone: section.modelData === "connected" ? "accent" : "secondary"
                            accessibleName: ""
                        }

                        Shared.TextLabel {
                            Layout.fillWidth: true
                            text: section.sectionTitle
                            variant: "label"
                            strong: true
                            Accessible.role: Accessible.Heading
                            Accessible.name: section.sectionTitle
                        }

                        Rectangle {
                            Layout.preferredWidth: Metrics.spacingLarge
                            Layout.preferredHeight: Metrics.borderWidth
                            color: Theme.border
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Metrics.spacingMedium

                        Repeater {
                            model: section.sectionDevices

                            delegate: BluetoothDeviceRow {
                                required property var modelData
                                Layout.fillWidth: true
                                device: modelData
                            }
                        }
                    }
                }
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: BluetoothService.powered && BluetoothService.devices.length === 0
                text: I18n.tr(BluetoothService.discovering
                    ? "bluetooth.devices.scanning" : "bluetooth.devices.empty")
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: !BluetoothService.available
                text: I18n.tr("bluetooth.unavailable")
                tone: "secondary"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
