pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Audio
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme
import "AudioGeometry.js" as AudioGeometry

Item {
    id: root

    property bool streamsExpanded: true
    property real availableViewportHeight: 440
    readonly property int maximumHeight: 520
    readonly property real implicitContentWidth: 380
    readonly property bool hasStreams: streamList.count > 0
    readonly property real outputDeviceHeight: AudioGeometry.deviceListHeight(
        outputDeviceList.count, Metrics.controlHeight, Metrics.spacingXSmall, 132)
    readonly property real fixedContentHeight: outputRow.implicitHeight
        + outputDevicesLabel.implicitHeight + root.outputDeviceHeight
        + inputRow.implicitHeight
        + (root.hasStreams ? Metrics.borderWidth + applicationsButton.implicitHeight : 0)
        + Metrics.spacingMedium * (root.hasStreams ? 5 : 3)
        + (root.hasStreams && root.streamsExpanded ? Metrics.spacingMedium : 0)
    // Natural request must not depend on the animated parent viewport: otherwise
    // expanding Applications cannot grow the chassis and clips its own controls.
    readonly property real streamHeight: root.streamsExpanded
        ? AudioGeometry.streamListHeight(streamList.count, 72, Metrics.spacingSmall) : 0
    readonly property real implicitContentHeight: contentColumn.implicitHeight + 32
    implicitWidth: implicitContentWidth
    implicitHeight: implicitContentHeight

    signal dismissRequested()

    Flickable {
        id: contentViewport
        anchors.fill: parent
        contentWidth: width
        contentHeight: Math.max(height, root.implicitContentHeight)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentColumn
            x: 16
            y: 16
            width: Math.max(0, contentViewport.width - 32)
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
                    model: AudioService.playbackStreamIds
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: AudioStreamRow {
                        required property var modelData
                        width: streamList.width
                        stream: AudioService.playbackStreams.find(item => item.id === modelData) || null
                    }
                }
            }
        }
    }
}
