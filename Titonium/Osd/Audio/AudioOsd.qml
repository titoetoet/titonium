pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    required property real volume
    required property bool muted
    property bool requestedPresented: false
    property bool presented: false
    property bool completed: false
    readonly property int percentage: Math.round(root.volume * 100)
    readonly property real trackProgress: Math.max(0, Math.min(1, root.volume))

    opacity: root.presented ? 1 : 0
    y: root.presented ? 0 : 8

    Behavior on opacity {
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusLarge
        color: Theme.surfaceElevated
        border.width: Metrics.borderWidth
        border.color: Theme.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Metrics.spacingLarge
            anchors.rightMargin: Metrics.spacingLarge
            spacing: Metrics.spacingMedium

            Shared.Icon {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                name: root.muted ? "volume_off" : "volume_up"
                size: 22
                tone: root.muted ? "secondary" : "accent"
                accessibleName: ""
            }

            Item {
                id: track
                Layout.fillWidth: true
                Layout.preferredHeight: 8

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Theme.surfaceInteractive
                }

                Rectangle {
                    width: track.width * root.trackProgress
                    height: track.height
                    radius: height / 2
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Motion.reduced ? 0 : 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Shared.TextLabel {
                Layout.preferredWidth: 52
                horizontalAlignment: Text.AlignRight
                strong: true
                text: root.muted ? I18n.tr("audio.muted")
                    : I18n.tr("audio.osd.volume", { "percentage": root.percentage })
            }
        }
    }

    onRequestedPresentedChanged: {
        if (root.completed)
            root.presented = root.requestedPresented;
    }

    Component.onCompleted: {
        root.completed = true;
        root.presented = root.requestedPresented;
    }
}
