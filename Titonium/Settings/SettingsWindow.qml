pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Surfaces

PanelWindow {
    id: window

    required property ShellScreen screenModel
    readonly property bool ownsSettings:
        SettingsCoordinator.ownerScreenName === window.screenModel.name
    readonly property string focusOwnerId: "settings:" + window.screenModel.name
    readonly property bool wantsInteractiveFocus: window.ownsSettings
    readonly property bool effectiveInteractiveFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId)

    onWantsInteractiveFocusChanged:
        FocusArbiter.request(window.focusOwnerId, window.wantsInteractiveFocus)
    onEffectiveInteractiveFocusChanged: FocusDiagnostics.observe(
        window.focusOwnerId, window.effectiveInteractiveFocus,
        { mode: window.ownsSettings ? "open" : "closed", focusPolicy: "exclusive" })
    Component.onCompleted:
        FocusArbiter.request(window.focusOwnerId, window.wantsInteractiveFocus)

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
    WlrLayershell.keyboardFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: settingsLoader }

    Loader {
        id: settingsLoader
        anchors.fill: parent
        active: window.ownsSettings
        sourceComponent: SettingsCenter {}
    }

    Component.onDestruction: {
        FocusArbiter.withdraw(window.focusOwnerId);
        FocusDiagnostics.observe(window.focusOwnerId, false, { mode: "destroyed" });
        if (window.ownsSettings)
            SettingsCoordinator.forceCancelAndClose();
    }
}
