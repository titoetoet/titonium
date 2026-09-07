pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Shared.styles
Item {
    id: root
    required property var paint
    required property var geometry
    required property var motion
    PaintTransition {
        id: stateTransition
        objectName: "styleStateTransition"
        targetValue: root.paint.stateLayerOpacity
        motion: root.motion
    }
    objectName: "glassmorphismPaint"
    PaintTransition {
        id: interactionTransition
        targetValue: root.paint.pressed ? 1 : root.paint.hovered ? .4 : 0
        motion: root.motion
    }
    readonly property real interactionProgress: interactionTransition.value
    readonly property real sheen: paint.sheenStrength * (1 - interactionProgress * .35)
    readonly property string backdropTreatment: "opaque-safe-fallback"
    SoftShadow {
        anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: -3
        geometry: root.geometry; strength: root.paint.shadowStrength * .45; spread: 5
    }
    PaintShape {
        id: body
        anchors.fill: parent
        geometry: root.geometry
        color: root.paint.fill
        opacity: root.paint.opacity
        border.color: root.paint.outline
        border.width: root.paint.borderStrength > 0 ? Math.min(1, root.paint.borderStrength) : 0
    }
    PaintShape {
        objectName: "frostedSheen"
        anchors.fill: parent; geometry: root.geometry
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1,1,1,root.sheen * .14) }
            GradientStop { position: .70; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(1,1,1,root.sheen * .025) }
        }
    }
    PaintShape {
        anchors.fill: parent; geometry: root.geometry
        color: root.paint.foreground; opacity: stateTransition.value * .6
    }
}
