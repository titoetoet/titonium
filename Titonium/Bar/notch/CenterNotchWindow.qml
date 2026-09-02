pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Services.Hyprland
import qs.Titonium.Theme

PanelWindow {
    id: window
    required property ShellScreen screenModel
    readonly property bool ownsNotch: CenterNotchCoordinator.ownerScreenName === screenModel.name
    readonly property bool dismissing:
        CenterNotchCoordinator.exitingScreenName === screenModel.name

    screen: window.screenModel
    visible: window.ownsNotch || window.dismissing
    color: "transparent"
    aboveWindows: true
    WlrLayershell.namespace: "titonium-center-notch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.ownsNotch
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {
        Region { item: activeInputRegion }
    }

    Item {
        id: activeInputRegion
        width: window.ownsNotch ? window.width : 0
        height: window.ownsNotch ? window.height : 0
    }

    Loader {
        id: surfaceLoader
        anchors.fill: parent
        active: window.ownsNotch || window.dismissing
        sourceComponent: CenterNotchSurface {
            screenModel: window.screenModel
            closeRequested: window.dismissing
        }
    }

    Connections {
        target: surfaceLoader.item

        function onCloseAnimationFinished(): void {
            CenterNotchCoordinator.finishClose(window.screenModel.name);
        }
    }

    onOwnsNotchChanged: {
        if (window.ownsNotch) {
            return;
        }
        if (Motion.reduced) {
            CenterNotchCoordinator.finishClose(window.screenModel.name);
            return;
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
