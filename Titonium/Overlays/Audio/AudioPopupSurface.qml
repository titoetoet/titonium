pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Audio
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property int maximumHeight: 520
    readonly property real panelTop: 40 + Metrics.barSpacing
    readonly property real availableHeight: Math.max(0,
        root.height - root.panelTop - Metrics.barPadding)
    readonly property real fixedContentHeight: Metrics.spacingLarge * 2
        + outputRow.implicitHeight + inputRow.implicitHeight + Metrics.borderWidth
        + applicationsLabel.implicitHeight + Metrics.spacingMedium * 4
    readonly property real maximumStreamHeight: Math.max(0,
        Math.min(root.maximumHeight, root.availableHeight) - root.fixedContentHeight)
    readonly property real streamContentHeight: streamList.count > 0
        ? Math.max(0, streamList.contentHeight) : emptyLabel.implicitHeight
    readonly property real streamHeight: Math.min(root.streamContentHeight,
        root.maximumStreamHeight)

    anchors.fill: parent
    focus: true

    function close(): void {
        if (root.ownerId)
            SurfaceManager.close(root.ownerId);
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
            root.fixedContentHeight + root.streamHeight)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: root.panelTop
        anchors.rightMargin: Metrics.barPadding
        customColor: Theme.surface
        clipContent: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingLarge
            spacing: Metrics.spacingMedium

            AudioControlRow {
                id: outputRow
                Layout.fillWidth: true
                kind: "output"
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
            }

            Shared.TextLabel {
                id: applicationsLabel
                Layout.fillWidth: true
                text: I18n.tr("audio.applications")
                variant: "label"
                strong: true
            }

            Item {
                id: streamViewport
                Layout.fillWidth: true
                Layout.preferredHeight: root.streamHeight
                Layout.minimumHeight: 0

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

                Shared.TextLabel {
                    id: emptyLabel
                    anchors.centerIn: parent
                    visible: streamList.count === 0
                    text: I18n.tr(AudioService.ready ? "audio.applications.empty" : "audio.unavailable")
                    tone: "secondary"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: panel.forceActiveFocus(Qt.PopupFocusReason)
}
