pragma ComponentBehavior: Bound
import QtQuick

// A single finite numeric paint transition. Reduced Motion also cancels a running transition.
QtObject {
    id: root
    required property real targetValue
    required property var motion
    property real value: targetValue
    property bool ready: false
    // Monotonic fifth-order settling approximates critical damping without mask overshoot.
    readonly property int easingType: motion.curve === "emphasized" ? Easing.InOutCubic
        : motion.curve === "spring-damped" ? Easing.OutQuint : Easing.OutCubic
    property NumberAnimation animation: NumberAnimation {
        target: root; property: "value"
        duration: root.motion.durationMs
        easing.type: root.easingType
    }
    function settleOrAnimate(): void {
        if (!ready) return;
        if (motion.durationMs === 0) {
            animation.stop();
            value = targetValue;
        } else if (value !== targetValue) {
            animation.to = targetValue;
            animation.restart();
        }
    }
    onTargetValueChanged: settleOrAnimate()
    onMotionChanged: settleOrAnimate()
    Component.onCompleted: { value = targetValue; ready = true; }
}
