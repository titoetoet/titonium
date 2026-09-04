pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.AgentApproval
import qs.Titonium.Theme

PanelWindow {
    id: window
    required property ShellScreen screenModel
    readonly property real popupTop: Metrics.barHeight + Metrics.barSpacing
    readonly property bool ownsApproval: AgentApprovalService.hasPending
        && AgentApprovalService.popupScreenName === window.screenModel.name

    readonly property bool isFileChange: AgentApprovalService.currentIsFileChange
    readonly property string focusOwnerId: "agent-approval:" + window.screenModel.name
    property string focusLease: ""
    readonly property bool wantsInteractiveFocus: !window.isFileChange && window.ownsApproval
    readonly property bool effectiveInteractiveFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId, window.focusLease)

    onWantsInteractiveFocusChanged: {
        if (window.focusLease)
            FocusArbiter.request(window.focusOwnerId, window.focusLease,
                window.wantsInteractiveFocus);
    }
    onEffectiveInteractiveFocusChanged: FocusDiagnostics.observe(
        window.focusOwnerId, window.effectiveInteractiveFocus,
        { mode: window.isFileChange ? "file-change" : "approval", focusPolicy: "on-demand" })
    Component.onCompleted: {
        window.focusLease = FocusArbiter.newLease("agent-approval");
        FocusArbiter.request(window.focusOwnerId, window.focusLease,
            window.wantsInteractiveFocus);
    }

    screen: window.screenModel
    visible: window.ownsApproval
    color: "transparent"
    implicitWidth: window.isFileChange ? (380 + Metrics.barPadding * 2) : 660
    implicitHeight: window.popupTop + (window.isFileChange ? 180 : 340)
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-agent-approval"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: window.wantsInteractiveFocus
        && FocusArbiter.granted(window.focusOwnerId, window.focusLease)
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors {
        top: true
        right: window.isFileChange
        left: false
        bottom: false
    }
    mask: Region { Region { item: cardLoader } }

    Loader {
        id: cardLoader
        width: window.isFileChange ? 380 : 640
        height: window.isFileChange ? cardLoader.implicitHeight : 320
        anchors.top: parent.top
        anchors.right: window.isFileChange ? parent.right : undefined
        anchors.horizontalCenter: window.isFileChange ? undefined : parent.horizontalCenter
        anchors.topMargin: window.popupTop
        anchors.rightMargin: window.isFileChange ? Metrics.barPadding : 0
        active: window.ownsApproval
        sourceComponent: window.isFileChange ? toastComponent : modalComponent
    }

    Component {
        id: toastComponent
        AgentApprovalToastCard {}
    }

    Component {
        id: modalComponent
        AgentApprovalCard {}
    }

    Component.onDestruction: {
        FocusArbiter.withdraw(window.focusOwnerId, window.focusLease);
        FocusDiagnostics.observe(window.focusOwnerId, false, { mode: "destroyed" });
    }
}
