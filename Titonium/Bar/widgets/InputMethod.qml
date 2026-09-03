pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Bar.right
import qs.Titonium.Services.InputMethod
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen
    property real menuAnchorOffset: 0
    transform: Translate { x: root.menuAnchorOffset }
    // keyboard_keys remains the fallback glyph for compatible themes.
    readonly property string keyboardIcon: InputMethodService.vietnamese
        ? "local_florist" : (InputMethodService.english ? "keyboard" : "keyboard_off")

    implicitWidth: Metrics.controlHeightSmall
    implicitHeight: Metrics.widgetHeight

    MouseArea {
        id: inputHover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            RightPillCoordinator.setInvocationContext(root.screen, root);
            RightPillCoordinator.toggleInput(root.screen.name, "right");
        }
    }

    Shared.Icon {
        id: inputIcon
        anchors.centerIn: parent
        name: root.keyboardIcon
        size: 20
        tone: !InputMethodService.available ? "disabled"
            : (InputMethodService.vietnamese ? "accent" : "primary")
        accessibleName: I18n.tr("menubar.input_method.accessible", {
            name: InputMethodService.displayName
        })
        scale: Motion.reduced ? 1 : (inputHover.pressed ? 0.96
            : (inputHover.containsMouse ? 1.08 : 1))
        transform: Translate { y: !Motion.reduced && inputHover.containsMouse ? -1 : 0 }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.reduced ? 0 : 140
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.springDamped
            }
        }
    }
}
