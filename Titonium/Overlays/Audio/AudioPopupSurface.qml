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
    readonly property real availableHeight: Math.max(0,
        root.height - root.panelTop - Metrics.barPadding)
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

    function close(): void {
        if (Motion.reduced) {
            if (root.ownerId)
                SurfaceManager.close(root.ownerId);
            return;
        }
        if (root.closing)
            return;
        root.closing = true;
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
        transformOrigin: Item.Top
        opacity: Motion.reduced ? 1 : 0
        scale: Motion.reduced ? 1 : 0.98
        transform: Translate {
            id: panelEntranceOffset
            y: Motion.reduced ? 0 : -8
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
                id: streamViewport
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
            duration: 140
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 0.98
            to: 1
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: -8
            to: 0
            duration: 180
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.springDamped
        }
    }

    ParallelAnimation {
        id: panelExit

        NumberAnimation {
            target: panel
            property: "opacity"
            from: 1
            to: 0
            duration: 100
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel
            property: "scale"
            from: 1
            to: 0.98
            duration: 100
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panelEntranceOffset
            property: "y"
            from: 0
            to: -6
            duration: 100
            easing.type: Easing.InCubic
        }
        onFinished: {
            if (root.ownerId)
                SurfaceManager.close(root.ownerId);
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: panel.forceActiveFocus(Qt.PopupFocusReason)
}
