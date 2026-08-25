pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

FocusScope {
    id: root

    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 0
    property string accessibleName: ""
    signal moved(real value)
    signal committed(real value)

    readonly property real range: Math.max(0, root.to - root.from)
    readonly property real normalizedValue: root.range > 0
        ? Math.max(0, Math.min(1, (root.value - root.from) / root.range))
        : 0

    function snappedValue(candidate: real): real {
        const bounded = Math.max(root.from, Math.min(root.to, candidate));
        if (root.stepSize <= 0)
            return bounded;
        const steps = Math.round((bounded - root.from) / root.stepSize);
        return Math.max(root.from, Math.min(root.to, root.from + steps * root.stepSize));
    }

    function setValue(candidate: real, shouldCommit: bool): void {
        if (!root.enabled || root.range <= 0)
            return;
        const nextValue = root.snappedValue(candidate);
        if (nextValue !== root.value) {
            root.value = nextValue;
            root.moved(nextValue);
        }
        if (shouldCommit)
            root.committed(root.value);
    }

    function valueAt(positionX: real): real {
        const fraction = Math.max(0, Math.min(1, positionX / Math.max(1, root.width)));
        return root.from + fraction * root.range;
    }

    implicitWidth: 220
    implicitHeight: 32
    activeFocusOnTab: root.enabled && root.range > 0
    opacity: root.enabled ? 1.0 : 0.55

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: Metrics.radiusSmall
        color: Theme.surfaceInteractive
        border.width: Metrics.borderWidth
        border.color: root.activeFocus ? Theme.focus : Theme.border

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.normalizedValue
            radius: parent.radius
            color: Theme.accent
        }
    }

    Rectangle {
        width: 16
        height: 16
        radius: width / 2
        anchors.verticalCenter: track.verticalCenter
        x: (root.width - width) * root.normalizedValue
        color: Theme.surface
        border.width: 2
        border.color: root.activeFocus ? Theme.focus : Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled && root.range > 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        onPressed: mouse => {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.setValue(root.valueAt(mouse.x), false);
        }
        onPositionChanged: mouse => {
            if (pressed)
                root.setValue(root.valueAt(mouse.x), false);
        }
        onReleased: root.setValue(root.value, true)
    }

    Keys.onPressed: event => {
        const keyboardStep = root.stepSize > 0 ? root.stepSize : root.range / 100;
        let candidate = root.value;
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Down)
            candidate -= keyboardStep;
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Up)
            candidate += keyboardStep;
        else if (event.key === Qt.Key_Home)
            candidate = root.from;
        else if (event.key === Qt.Key_End)
            candidate = root.to;
        else
            return;
        root.setValue(candidate, true);
        event.accepted = true;
    }

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleName + ", " + String(root.value)
}
