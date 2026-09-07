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
    property string focusLease: ""
    readonly property bool wantsInteractiveFocus: window.ownsSettings
    readonly property bool effectiveInteractiveFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId, window.focusLease)

    onWantsInteractiveFocusChanged: {
        if (window.focusLease)
            FocusArbiter.request(window.focusOwnerId, window.focusLease,
                window.wantsInteractiveFocus);
    }
    onEffectiveInteractiveFocusChanged: FocusDiagnostics.observe(
        window.focusOwnerId, window.focusLease, window.effectiveInteractiveFocus,
        { mode: window.ownsSettings ? "open" : "closed", focusPolicy: "exclusive" })
    Component.onCompleted: {
        window.focusLease = FocusArbiter.newLease("settings");
        FocusArbiter.request(window.focusOwnerId, window.focusLease,
            window.wantsInteractiveFocus);
    }

    screen: window.screenModel
    visible: window.ownsSettings
    color: "transparent"
    implicitWidth: Math.min(980, window.screenModel.width - 48)
    implicitHeight: Math.min(700, window.screenModel.height - 48)
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId, window.focusLease)
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: settingsLoader }

    Loader {
        id: settingsLoader
        anchors.fill: parent
        active: window.ownsSettings
        sourceComponent: SettingsCenter {}
    }

    Component.onDestruction: {
        FocusArbiter.withdraw(window.focusOwnerId, window.focusLease);
        FocusDiagnostics.observe(window.focusOwnerId, window.focusLease, false,
            { mode: "destroyed" });
        if (window.ownsSettings)
            SettingsCoordinator.closeForOwnerLoss();
    }
}
