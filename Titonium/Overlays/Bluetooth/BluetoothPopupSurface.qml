pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Bluetooth
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property var invoker: root.descriptor?.invoker || null
    readonly property int maximumHeight: 520
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property real availableHeight: Math.max(0,
        root.height - root.panelTop - Metrics.barPadding)
    readonly property real contentHeight: contentColumn.implicitHeight + 2 * panel.padding

    anchors.fill: parent
    focus: true

    function returnFocus(): void {
        if (root.invoker && root.invoker.forceActiveFocus)
            root.invoker.forceActiveFocus(Qt.PopupFocusReason);
    }

    function close(): void {
        root.returnFocus();
        if (root.ownerId)
            SurfaceManager.close(root.ownerId);
    }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    function devicesFor(section: string): var {
        return BluetoothService.devices.filter(device => device.section === section);
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position))
                    root.close();
            }
        }
    }

    Shared.Panel {
        id: panel
        width: 380
        height: Math.min(root.maximumHeight, root.availableHeight, root.contentHeight)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.panelTop
        anchors.rightMargin: Metrics.barPadding
        customColor: Theme.surface
        clipContent: true

        Behavior on height { NumberAnimation { duration: Motion.normal } }

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
                        iconName: BluetoothService.discovering ? "close" : "bluetooth_searching"
                        variant: "quiet"
                        size: "small"
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

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: panel.forceActiveFocus(Qt.PopupFocusReason)
    Component.onDestruction: root.returnFocus()
}
