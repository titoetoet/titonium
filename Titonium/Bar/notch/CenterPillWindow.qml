pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Hyprland
import qs.Titonium.Theme
import "CenterStyleProfile.js" as CenterStyleProfile

PanelWindow {
    id: window

    required property ShellScreen screenModel
    property string styleName: "connected"
    signal bannerRequested(var screen, var context, bool autoDismiss)
    signal settingsRequested(var screen)

    readonly property var styleProfile: CenterStyleProfile.profile(
        window.styleName, window.width, window.height)
    readonly property bool ownsIsland:
        CenterNotchCoordinator.ownerScreenName === window.screenModel.name
    readonly property bool dismissing:
        CenterNotchCoordinator.exitingScreenName === window.screenModel.name
    readonly property real compactY: BarVisibilityState.revealed || window.ownsIsland
        ? window.styleProfile.compactY : -Metrics.barHeight + 2

    screen: window.screenModel
    visible: true
    color: "transparent"
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-center-pill"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.ownsIsland
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {
        Region { item: activeInputRegion }
        Region { item: dismissingInputRegion }
        Region { item: compactInputRegion }
    }

    Item {
        id: activeInputRegion
        width: window.ownsIsland ? window.width : 0
        height: window.ownsIsland ? window.height : 0
    }

    Item {
        id: dismissingInputRegion
        visible: window.dismissing
        x: surface.visualX
        y: surface.visualY
        width: window.dismissing ? surface.visualWidth : 0
        height: window.dismissing ? surface.visualHeight : 0
    }

    Item {
        id: compactInputRegion
        visible: !window.ownsIsland && !window.dismissing
        x: surface.compactInputX
        y: window.compactY
        width: !window.ownsIsland ? surface.compactInputWidth : 0
        height: !window.ownsIsland ? surface.compactInputHeight : 0
    }


    CenterNotchSurface {
        id: surface
        anchors.fill: parent
        screenModel: window.screenModel
        ownsIsland: window.ownsIsland
        closeRequested: window.dismissing
        compactY: window.compactY
        styleName: window.styleProfile.style
        onBannerRequested: (screen, context, autoDismiss) =>
            window.bannerRequested(screen, context, autoDismiss)
        onSettingsRequested: screen => window.settingsRequested(screen)
        onCloseAnimationFinished: CenterNotchCoordinator.finishClose(window.screenModel.name)
    }

    Connections {
        target: HyprlandService
        function onFocusedMonitorNameChanged(): void {
            if (window.ownsIsland
                    && HyprlandService.focusedMonitorName.length > 0
                    && HyprlandService.focusedMonitorName !== window.screenModel.name)
                CenterNotchCoordinator.collapse();
        }
    }

}
