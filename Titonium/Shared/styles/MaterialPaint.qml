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
    objectName: "materialPaint"
    property real rippleProgress: .35
    property bool lastPressed: false
    function updateRipple(): void {
        if (!rippleAnimation) return;
        if (motion.durationMs === 0) {
            rippleAnimation.stop();
            rippleProgress = paint.pressed ? 1 : .35;
        } else if (paint.pressed !== lastPressed) {
            rippleAnimation.to = paint.pressed ? 1 : .35;
            rippleAnimation.restart();
        }
        lastPressed = paint.pressed;
    }
    onPaintChanged: updateRipple()
    onMotionChanged: updateRipple()
    Component.onCompleted: updateRipple()
    NumberAnimation {
        id: rippleAnimation
        target: root; property: "rippleProgress"
        duration: root.motion.durationMs; easing.type: stateTransition.easingType
    }
    readonly property real elevation: paint.shadowStrength * (paint.pressed ? 1 : paint.hovered ? 5 : 3)
    SoftShadow {
        objectName: "materialElevation"
        anchors.fill: parent; anchors.topMargin: root.elevation; anchors.bottomMargin: -root.elevation
        geometry: root.geometry; spread: root.elevation + 1
        strength: root.paint.shadowStrength * .6
    }
    PaintShape {
        id: body
        anchors.fill: parent
        geometry: root.geometry
        color: root.paint.fill
        border.color: root.paint.outline
        border.width: root.paint.borderStrength > 0 ? Math.min(1, root.paint.borderStrength) : 0
    }
    PaintShape {
        objectName: "materialStateLayer"
        anchors.fill: parent; geometry: root.geometry
        color: root.paint.foreground; opacity: stateTransition.value
    }
    PaintShape {
        id: ripple
        objectName: "materialRipple"
        anchors.fill: parent; geometry: root.geometry
        color: root.paint.foreground
        opacity: root.paint.pressed ? .10 : 0
        scale: root.rippleProgress
    }
}
