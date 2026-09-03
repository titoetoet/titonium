pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real bodyWidth: 200
    property real bodyHeight: 40
    property real shoulderSize: 18
    property real bottomRadius: 18
    property color color: "#000000"

    readonly property real bodyLeft: root.shoulderSize
    readonly property real bodyRight: root.shoulderSize + root.bodyWidth
    readonly property real totalWidth: root.bodyWidth + root.shoulderSize * 2
    readonly property real safeRadius: Math.max(0, Math.min(root.bottomRadius,
        root.bodyWidth / 2, root.bodyHeight - root.shoulderSize))

    implicitWidth: root.totalWidth
    implicitHeight: root.bodyHeight
    width: root.totalWidth
    height: root.bodyHeight

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: root.color
            pathHints: ShapePath.PathSolid | ShapePath.PathNonIntersecting
            startX: 0
            startY: 0

            PathLine { x: root.totalWidth; y: 0 }
            PathCubic {
                control1X: root.totalWidth - root.shoulderSize * 0.55
                control1Y: 0
                control2X: root.bodyRight
                control2Y: root.shoulderSize * 0.35
                x: root.bodyRight
                y: root.shoulderSize
            }
            PathLine { x: root.bodyRight; y: root.bodyHeight - root.safeRadius }
            PathQuad {
                controlX: root.bodyRight
                controlY: root.bodyHeight
                x: root.bodyRight - root.safeRadius
                y: root.bodyHeight
            }
            PathLine { x: root.bodyLeft + root.safeRadius; y: root.bodyHeight }
            PathQuad {
                controlX: root.bodyLeft
                controlY: root.bodyHeight
                x: root.bodyLeft
                y: root.bodyHeight - root.safeRadius
            }
            PathLine { x: root.bodyLeft; y: root.shoulderSize }
            PathCubic {
                control1X: root.bodyLeft
                control1Y: root.shoulderSize * 0.35
                control2X: root.shoulderSize * 0.55
                control2Y: 0
                x: 0
                y: 0
            }
        }
    }
}
