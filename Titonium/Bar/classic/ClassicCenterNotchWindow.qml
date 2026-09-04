pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Bar.notch
import qs.Titonium.Services.Hyprland
import qs.Titonium.Theme

PanelWindow {
    id: window

    required property ShellScreen screenModel
    property bool styleActive: true
    signal bannerRequested(var screen, var context, bool autoDismiss)
    signal settingsRequested(var screen)

    readonly property bool ownsNotch: window.styleActive
        && CenterNotchCoordinator.ownerScreenName === window.screenModel.name
    readonly property bool dismissing: window.styleActive
        && CenterNotchCoordinator.exitingScreenName === window.screenModel.name

    screen: window.screenModel
    visible: window.styleActive && (window.ownsNotch || window.dismissing)
    color: "transparent"
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-classic-center-notch"
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

    ClassicCenterNotchSurface {
        id: surface
        anchors.fill: parent
        screenModel: window.screenModel
        closeRequested: window.dismissing
        onBannerRequested: (screen, context, autoDismiss) =>
            window.bannerRequested(screen, context, autoDismiss)
        onSettingsRequested: screen => window.settingsRequested(screen)
        onCloseAnimationFinished:
            CenterNotchCoordinator.finishClose(window.screenModel.name)
    }

    onOwnsNotchChanged: {
        if (!window.ownsNotch && window.dismissing && Motion.reduced)
            CenterNotchCoordinator.finishClose(window.screenModel.name);
    }

    onStyleActiveChanged: {
        if (window.styleActive)
            return;
        if (CenterNotchCoordinator.ownerScreenName === window.screenModel.name)
            CenterNotchCoordinator.collapse();
        if (CenterNotchCoordinator.exitingScreenName === window.screenModel.name)
            CenterNotchCoordinator.finishClose(window.screenModel.name);
    }

    Connections {
        target: HyprlandService
        function onFocusedMonitorNameChanged(): void {
            if (window.ownsNotch
                    && HyprlandService.focusedMonitorName.length > 0
                    && HyprlandService.focusedMonitorName !== window.screenModel.name)
                CenterNotchCoordinator.collapse();
        }
    }

    Component.onDestruction: {
        if (CenterNotchCoordinator.ownerScreenName === window.screenModel.name)
            CenterNotchCoordinator.collapse();
        if (CenterNotchCoordinator.exitingScreenName === window.screenModel.name)
            CenterNotchCoordinator.finishClose(window.screenModel.name);
    }
}
