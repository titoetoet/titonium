pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.Titonium.Theme

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
        root.branchWidth / 2, (root.branchBottom - root.compactHeight) / 2))
    readonly property real shoulderJoinRadius: Math.min(root.shoulderSize, root.safeRadius,
        Math.max(0, root.farSideClearance))
    readonly property real attachmentRadius: Math.max(0, Math.min(18,
        root.branchWidth / 2, root.branchBottom - root.shoulderSize))

    readonly property color materialColor: Qt.alpha(root.color, root.color.a * Theme.material.backgroundOpacity)
    readonly property real materialEdge: Theme.chassis.edge
    // One continuous path remains the sole chassis. Its gradient supplies sheen
    // and bottom-edge depth without duplicating silhouettes or input geometry.
    property LinearGradient materialGradient: LinearGradient {
        x1: 0; y1: 0; x2: Theme.chassis.diagonal ? root.width : 0; y2: root.height
        GradientStop { position: 0; color: Qt.tint(root.materialColor, Qt.alpha("#ffffff", Theme.chassis.top)) }
        GradientStop { position: Theme.chassis.shoulder; color: root.materialColor }
        GradientStop { position: Theme.chassis.foot; color: root.materialColor }
        GradientStop { position: 1; color: Qt.tint(root.materialColor, Qt.alpha("#000000", Theme.chassis.bottom)) }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            objectName: "appearancePath"
            strokeWidth: root.materialEdge > 0 ? 1 : 0
            strokeColor: Qt.alpha(Theme.borderStrong, root.materialEdge)
            fillColor: root.materialColor
            fillGradient: Theme.chassis.gradient
                ? root.materialGradient : null
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
                y: root.compactHeight + root.shoulderJoinRadius
            }
            // Match the opposing ScreenCorner curve, mirrored across the gap.
            PathCubic {
                control1X: root.branchFarX
                control1Y: root.compactHeight + root.shoulderJoinRadius * 0.45
                control2X: root.branchFarX + (root.leftEdge ? -1 : 1) * root.shoulderJoinRadius * 0.45
                control2Y: root.compactHeight
                x: root.branchFarX + (root.leftEdge ? -1 : 1) * root.shoulderJoinRadius
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
