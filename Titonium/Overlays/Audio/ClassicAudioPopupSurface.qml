pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Audio
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "AudioGeometry.js" as AudioGeometry

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    property bool streamsExpanded: false
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property int maximumHeight: 520
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property real availableHeight: Math.max(0, root.height - root.panelTop - Metrics.barPadding)
    readonly property bool hasStreams: streamList.count > 0
    readonly property real outputDeviceHeight: AudioGeometry.deviceListHeight(
        outputDeviceList.count, Metrics.controlHeight, Metrics.spacingXSmall, 132)
    readonly property real fixedContentHeight: outputRow.implicitHeight
        + outputDevicesLabel.implicitHeight + root.outputDeviceHeight
        + inputRow.implicitHeight
        + (root.hasStreams ? Metrics.borderWidth + applicationsButton.implicitHeight : 0)
        + Metrics.spacingMedium * (root.hasStreams ? 5 : 3)
        + (root.hasStreams && root.streamsExpanded ? Metrics.spacingMedium : 0)
    readonly property real maximumStreamHeight: Math.max(0,
        Math.min(root.maximumHeight, root.availableHeight)
            - root.fixedContentHeight - 2 * panel.padding)
    readonly property real streamContentHeight: Math.max(0, streamList.contentHeight)
    readonly property real streamHeight: root.streamsExpanded
        ? Math.min(root.streamContentHeight, root.maximumStreamHeight) : 0

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
        const target = root.closingInvoker || root.descriptor?.invoker || null;
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
        root.closingInvoker = root.descriptor?.invoker || null;
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
        height: Math.min(root.maximumHeight, root.availableHeight,
            root.fixedContentHeight + root.streamHeight + 2 * panel.padding)
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

        ColumnLayout {
            anchors.fill: parent
            spacing: Metrics.spacingMedium

            AudioControlRow {
                id: outputRow
                Layout.fillWidth: true
                kind: "output"
            }
            Shared.TextLabel {
                id: outputDevicesLabel
                Layout.fillWidth: true
                text: I18n.tr("audio.output.devices")
                variant: "label"
                strong: true
                Accessible.role: Accessible.Heading
            }
            ListView {
                id: outputDeviceList
                Layout.fillWidth: true
                Layout.preferredHeight: root.outputDeviceHeight
                Layout.minimumHeight: 0
                clip: true
                spacing: Metrics.spacingXSmall
                model: AudioService.outputDevices
                boundsBehavior: Flickable.StopAtBounds

                delegate: AudioOutputDeviceRow {
                    required property var modelData
                    width: outputDeviceList.width
                    device: modelData
                }
            }
            AudioControlRow {
                id: inputRow
                Layout.fillWidth: true
                kind: "input"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.borderWidth
                color: Theme.border
                visible: root.hasStreams
            }
            Shared.Button {
                id: applicationsButton
                Layout.fillWidth: true
                visible: root.hasStreams
                label: I18n.tr("audio.applications")
                iconName: root.streamsExpanded ? "expand_less" : "expand_more"
                variant: "quiet"
                size: "small"
                contentAlignment: Qt.AlignLeft
                accessibleName: I18n.tr(root.streamsExpanded
                    ? "audio.applications.collapse.accessible"
                    : "audio.applications.expand.accessible")
                onTriggered: root.streamsExpanded = !root.streamsExpanded
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.streamHeight
                Layout.minimumHeight: 0
                visible: root.hasStreams && root.streamsExpanded

                ListView {
                    id: streamList
                    anchors.fill: parent
                    clip: true
                    spacing: Metrics.spacingSmall
                    model: AudioService.playbackStreams
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: AudioStreamRow {
                        required property var modelData
                        width: streamList.width
                        stream: modelData
                    }
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
