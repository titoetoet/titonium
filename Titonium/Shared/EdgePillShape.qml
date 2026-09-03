pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string edge: "left"
    property real bodyWidth: 200
    property real bodyHeight: 36
    property real shoulderSize: 16
    property real innerRadius: bodyHeight / 2
    property color color: "#000000"

    readonly property bool leftEdge: root.edge === "left"
    readonly property real totalWidth: root.bodyWidth + root.shoulderSize
    readonly property real innerX: root.leftEdge ? root.bodyWidth : root.shoulderSize
    readonly property real safeRadius: Math.max(0, Math.min(root.innerRadius,
        root.bodyWidth, root.bodyHeight - root.shoulderSize))

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
            startX: root.leftEdge ? 0 : root.totalWidth
            startY: 0

            PathLine {
                x: root.leftEdge ? root.totalWidth : 0
                y: 0
            }
            PathCubic {
                control1X: root.leftEdge
                    ? root.totalWidth - root.shoulderSize * 0.55
                    : root.shoulderSize * 0.55
                control1Y: 0
                control2X: root.innerX
                control2Y: root.shoulderSize * 0.35
                x: root.innerX
                y: root.shoulderSize
            }
            PathLine {
                x: root.innerX
                y: root.bodyHeight - root.safeRadius
            }
            PathQuad {
                controlX: root.innerX
                controlY: root.bodyHeight
                x: root.leftEdge
                    ? root.innerX - root.safeRadius
                    : root.innerX + root.safeRadius
                y: root.bodyHeight
            }
            PathLine {
                x: root.leftEdge ? 0 : root.totalWidth
                y: root.bodyHeight
            }
            PathLine {
                x: root.leftEdge ? 0 : root.totalWidth
                y: 0
            }
        }
    }
}
