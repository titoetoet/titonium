pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window

    required property ShellScreen screenModel
    readonly property bool ownsSettings:
        SettingsCoordinator.ownerScreenName === window.screenModel.name

    screen: window.screenModel
    visible: window.ownsSettings
    color: "transparent"
    implicitWidth: 980
    implicitHeight: 700
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.ownsSettings
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: settingsLoader }

    Loader {
        id: settingsLoader
        anchors.fill: parent
        active: window.ownsSettings
        sourceComponent: SettingsCenter {}
    }

    Component.onDestruction: {
        if (window.ownsSettings)
            SettingsCoordinator.forceCancelAndClose();
    }
}
