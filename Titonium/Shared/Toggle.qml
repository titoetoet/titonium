pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme

FocusScope {
    id: root

    property bool checked: false
    property string accessibleName: ""
    signal toggled(bool checked)

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapHandler.pressed

    implicitWidth: 40
    implicitHeight: 22
    activeFocusOnTab: root.enabled
    opacity: root.enabled ? 1 : 0.5

    function activate(): void {
        if (root.enabled)
            root.toggled(!root.checked);
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent
            : (root.hovered ? Theme.surfaceInteractive : Theme.surfaceElevated)
        border.width: root.activeFocus ? Metrics.borderWidth : 0
        border.color: root.activeFocus ? Theme.focus : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    Rectangle {
        width: 16
        height: 16
        radius: width / 2
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.accentText : Theme.textSecondary
        Behavior on x { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        enabled: root.enabled
        onTapped: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.activate();
        }
    }

    Keys.onPressed: event => {
        if (root.enabled && (event.key === Qt.Key_Space || event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter)) {
            root.activate();
            event.accepted = true;
        }
    }

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.accessibleName
    Accessible.focusable: root.enabled
    Accessible.checkable: true
    Accessible.checked: root.checked
}
