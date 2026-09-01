pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.InputMethod
import qs.Titonium.Overlays.SystemTray
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen
    // keyboard_keys remains the fallback glyph for compatible themes.
    readonly property string keyboardIcon: InputMethodService.vietnamese
        ? "local_florist" : (InputMethodService.english ? "keyboard" : "keyboard_off")

    implicitWidth: Metrics.controlHeightSmall
    implicitHeight: Metrics.widgetHeight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: SystemTrayPopupCoordinator.toggleInput(root.screen, root)
    }

    Shared.Icon {
        anchors.centerIn: parent
        name: root.keyboardIcon
        size: 20
        tone: !InputMethodService.available ? "disabled"
            : (InputMethodService.vietnamese ? "accent" : "primary")
        accessibleName: I18n.tr("menubar.input_method.accessible", {
            name: InputMethodService.displayName
        })
    }
}
