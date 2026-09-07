pragma ComponentBehavior: Bound
import QtQuick
// Layered vector penumbra: also renders under Qt Quick's software backend.
Item {
    id: root
    required property var geometry
    property color tint: "black"
    property real strength: 0.3
    property real spread: 5
    Repeater {
        model: 6
        PaintShape {
            required property int index
            anchors.fill: parent
            anchors.margins: -root.spread * (index + 1) / 6
            geometry: root.geometry
            color: root.tint
            opacity: root.strength / 15
        }
    }
}
