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
    readonly property real availableHeight: Math.max(0, root.height - root.panelTop - Metrics.barPadding)
    readonly property real contentHeight: contentColumn.implicitHeight + 2 * panel.padding

    anchors.fill: parent
    focus: true

    property bool closing: false
    property bool focusReturned: false
    property var closingDescriptor: null
    property var closingScreen: null
    property var closingInvoker: null

    function returnFocus(): void {
        if (root.focusReturned)
            return;
        const ownedDescriptor = root.closingDescriptor || root.descriptor;
        const ownedScreen = root.closingScreen || root.screen;
        if (SurfaceManager.active
                && !SurfaceManager.matches(root.ownerId, ownedDescriptor, ownedScreen))
            return;
        root.focusReturned = true;
        const target = root.closingInvoker || root.invoker;
        if (target?.forceActiveFocus)
            target.forceActiveFocus(Qt.PopupFocusReason);
    }

    function finishClose(): void {
        if (!root.closingDescriptor || !SurfaceManager.matches(
                root.ownerId, root.closingDescriptor, root.closingScreen))
            return;
        root.returnFocus();
        SurfaceManager.closeOwned(root.ownerId, root.closingDescriptor, root.closingScreen);
    }

    function reopenIfReplaced(): void {
        if (!root.closing || root.descriptor === root.closingDescriptor)
            return;
        panelExit.stop();
        root.closing = false;
        root.closingDescriptor = null;
        root.closingScreen = null;
        root.closingInvoker = null;
        root.focusReturned = false;
        if (!Motion.reduced)
            panelEntrance.restart();
        panel.forceActiveFocus(Qt.PopupFocusReason);
    }

    function close(): void {
        if (root.closing)
            return;
        if (!SurfaceManager.beginClose(root.ownerId, root.descriptor, root.screen))
            return;
        root.closingDescriptor = root.descriptor;
        root.closingScreen = root.screen;
        root.closingInvoker = root.invoker;
        root.closing = true;
        if (Motion.reduced) {
            root.finishClose();
            return;
        }
        panelExit.restart();
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
        transformOrigin: Item.TopRight
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.94
        transform: Translate {
            id: panelEntranceOffset
            y: Motion.reduced ? 0 : -12
        }

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

    ParallelAnimation {
        id: panelEntrance
        running: !Motion.reduced

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.94
            to: 1
            duration: 220
            easing.bezierCurve: [0.38, 1.21, 0.22, 1, 1, 1]
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: -12
            to: 0
            duration: 220
            easing.bezierCurve: [0.2, 0.8, 0.2, 1, 1, 1]
        }
    }

    ParallelAnimation {
        id: panelExit

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 1
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 1
            to: 0.96
            duration: 130
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: 0
            to: -8
            duration: 130
            easing.type: Easing.InCubic
        }
        onFinished: root.finishClose()
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    onDescriptorChanged: root.reopenIfReplaced()
    Component.onCompleted: panel.forceActiveFocus(Qt.PopupFocusReason)
    Component.onDestruction: root.returnFocus()
}
