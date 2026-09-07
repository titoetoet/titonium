pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// The filled area is outside the rounded opening, like a popup shoulder.
Shape {
    id: root
    property color color: "#0d0e12"
    implicitWidth: 16
    implicitHeight: 16
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: 0
        fillColor: root.color
        startX: 0
        startY: 0
        PathLine { x: root.width; y: 0 }
        PathCubic {
            control1X: root.width * 0.45
            control1Y: 0
            control2X: 0
            control2Y: root.height * 0.45
            x: 0
            y: root.height
        }
        PathLine { x: 0; y: 0 }
    }
}
