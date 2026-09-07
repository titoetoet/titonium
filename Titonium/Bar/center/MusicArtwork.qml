pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

ClippingRectangle {
    id: root
    property string artwork: ""
    radius: Math.min(12, width / 5)
    color: Theme.surfaceElevated
    Image {
        id: cover
        anchors.fill: parent
        source: /^(file|https?):/.test(root.artwork) ? root.artwork : ""
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.ceil(root.width * 2)
        sourceSize.height: Math.ceil(root.height * 2)
    }
    Shared.Icon {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        name: "music_note"
        size: Math.min(36, root.width * 0.5)
        tone: "secondary"
    }
}
