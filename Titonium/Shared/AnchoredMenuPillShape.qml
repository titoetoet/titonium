pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string edge: "left"
    property real compactX: 0
    property real compactWidth: 200
    property real compactHeight: 36
    property real shoulderSize: 16
    property real branchX: 120
    property real branchY: 28
    property real branchWidth: 1
    property real branchHeight: 8
    property real branchRadius: 20
    property color color: "#000000"

    readonly property bool leftEdge: root.edge === "left"
    readonly property real attachmentX: root.leftEdge
        ? root.compactX + root.compactWidth - root.shoulderSize
        : root.compactX + root.shoulderSize
    readonly property real branchFarX: root.leftEdge
        ? root.branchX : root.branchX + root.branchWidth
    readonly property real branchBottom: root.branchY + root.branchHeight
    readonly property real farSideClearance: root.leftEdge
        ? root.branchFarX - root.compactX
        : root.compactX + root.compactWidth - root.branchFarX
    readonly property real safeRadius: Math.max(0, Math.min(root.branchRadius,
        root.branchWidth / 2, (root.branchBottom - root.compactHeight) / 2,
        root.farSideClearance))
    readonly property real attachmentRadius: Math.max(0, Math.min(18,
        root.branchWidth / 2, root.branchBottom - root.shoulderSize))

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: root.color
            pathHints: ShapePath.PathSolid | ShapePath.PathNonIntersecting
            startX: root.leftEdge ? root.compactX : root.compactX + root.compactWidth
            startY: 0

            PathLine {
                x: root.leftEdge ? root.compactX + root.compactWidth : root.compactX
                y: 0
            }
            PathCubic {
                control1X: root.leftEdge
                    ? root.compactX + root.compactWidth - root.shoulderSize * 0.55
                    : root.compactX + root.shoulderSize * 0.55
                control1Y: 0
                control2X: root.attachmentX
                control2Y: root.shoulderSize * 0.35
                x: root.attachmentX
                y: root.shoulderSize
            }
            PathLine {
                x: root.attachmentX
                y: root.branchBottom - root.attachmentRadius
            }
            PathQuad {
                controlX: root.attachmentX
                controlY: root.branchBottom
                x: root.leftEdge
                    ? root.attachmentX - root.attachmentRadius
                    : root.attachmentX + root.attachmentRadius
                y: root.branchBottom
            }
            PathLine {
                x: root.leftEdge
                    ? root.branchFarX + root.safeRadius
                    : root.branchFarX - root.safeRadius
                y: root.branchBottom
            }
            PathQuad {
                controlX: root.branchFarX
                controlY: root.branchBottom
                x: root.branchFarX
                y: root.branchBottom - root.safeRadius
            }
            PathLine {
                x: root.branchFarX
                y: root.compactHeight + root.safeRadius
            }
            PathQuad {
                controlX: root.branchFarX
                controlY: root.compactHeight
                x: root.leftEdge
                    ? root.branchFarX - root.safeRadius
                    : root.branchFarX + root.safeRadius
                y: root.compactHeight
            }
            PathLine {
                x: root.leftEdge ? root.compactX : root.compactX + root.compactWidth
                y: root.compactHeight
            }
            PathLine {
                x: root.leftEdge ? root.compactX : root.compactX + root.compactWidth
                y: 0
            }
        }
    }
}
