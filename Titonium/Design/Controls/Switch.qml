pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design

FocusScope {
    id: root

    property bool checked: false
    property string accessibleName: ""
    signal toggled(bool checked)

    function toggle(): void {
        if (!root.enabled)
            return;
        root.checked = !root.checked;
        root.toggled(root.checked);
    }

    implicitWidth: 40
    implicitHeight: 24
    activeFocusOnTab: root.enabled
    opacity: root.enabled ? 1.0 : 0.55

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surfaceInteractive
        border.width: Metrics.borderWidth
        border.color: root.activeFocus ? Theme.focus : (root.checked ? Theme.accent : Theme.borderStrong)

        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        Rectangle {
            width: 18
            height: 18
            radius: width / 2
            y: 2
            x: root.checked ? track.width - width - 3 : 3
            color: root.checked ? Theme.accentText : Theme.textSecondary

            Behavior on x {
                NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
            }
        }
    }

    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.enabled
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.toggle();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggle();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.accessibleName
    Accessible.checkable: true
    Accessible.checked: root.checked
}
