pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Services.MediaSpectrum
import qs.Titonium.Theme

Item {
    id: root
    property bool playing: false
    property var samples: MediaSpectrumService.spectrum
    implicitHeight: 32
    implicitWidth: 200
    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: 24
            Rectangle {
                required property int index
                width: Math.max(1, (root.width - 23 * 2) / 24)
                readonly property real sample: root.visible && root.playing && !Motion.reduced
                    ? Math.max(0, Math.min(1, Number(root.samples[index]) || 0)) : 0
                height: 3 + sample * Math.max(0, root.height - 3)
                y: root.height - height
                radius: width / 2
                color: Theme.textSecondary
                Behavior on height {
                    enabled: !Motion.reduced
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
