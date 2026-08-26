pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Services.Hyprland

PanelWindow {
    id: window
    required property ShellScreen screenModel
    readonly property bool ownsNotch: CenterNotchCoordinator.ownerScreenName === screenModel.name

    screen: window.screenModel
    visible: window.ownsNotch
    color: "transparent"
    aboveWindows: true
    WlrLayershell.namespace: "titonium-center-notch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.ownsNotch
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    Loader {
        anchors.fill: parent
        active: window.ownsNotch
        sourceComponent: CenterNotchSurface {
            screenModel: window.screenModel
        }
    }

    Connections {
        target: HyprlandService
        function onFocusedMonitorNameChanged(): void {
            if (window.ownsNotch
                    && HyprlandService.focusedMonitorName.length > 0
                    && HyprlandService.focusedMonitorName !== window.screenModel.name)
                CenterNotchCoordinator.close();
        }
    }

    Component.onDestruction: {
        if (window.ownsNotch)
            CenterNotchCoordinator.close();
    }
}
