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
        height: Math.min(root.maximumHeight, Math.max(160, root.height - (40 + Metrics.barSpacing)
            - Metrics.barPadding))
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 40 + Metrics.barSpacing
        anchors.rightMargin: Metrics.barPadding
        customColor: Theme.surface
        clipContent: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Metrics.spacingLarge
            spacing: Metrics.spacingMedium

            AudioControlRow {
                Layout.fillWidth: true
                kind: "output"
            }

            AudioControlRow {
                Layout.fillWidth: true
                kind: "input"
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Metrics.borderWidth
                color: Theme.border
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("audio.applications")
                variant: "label"
                strong: true
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
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
