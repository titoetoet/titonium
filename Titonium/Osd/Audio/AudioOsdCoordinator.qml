pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Hyprland
import qs.Titonium.Theme

QtObject {
    id: root

    property bool activeState: false
    property bool presentedState: false
    property string ownerScreenNameState: ""
    property real volumeState: 0
    property bool mutedState: false

    readonly property bool active: root.activeState
    readonly property bool presented: root.presentedState
    readonly property string ownerScreenName: root.ownerScreenNameState
    readonly property real volume: root.volumeState
    readonly property bool muted: root.mutedState

    function show(screenName: string, volume: real, muted: bool): bool {
        if (screenName.length === 0)
            return false;
        exitTimer.stop();
        root.ownerScreenNameState = screenName;
        root.volumeState = volume;
        root.mutedState = muted;
        root.activeState = true;
        root.presentedState = true;
        hideTimer.restart();
        return true;
    }

    function hide(): bool {
        if (!root.active)
            return false;
        hideTimer.stop();
        root.presentedState = false;
        exitTimer.restart();
        return true;
    }

    function release(): bool {
        if (!root.active)
            return false;
        root.activeState = false;
        root.presentedState = false;
        root.ownerScreenNameState = "";
        root.volumeState = 0;
        root.mutedState = false;
        return true;
    }

    property Timer hideTimer: Timer {
        id: hideTimer
        interval: 1200
        repeat: false
        onTriggered: root.hide()
    }

    property Timer exitTimer: Timer {
        id: exitTimer
        interval: Motion.fast
        repeat: false
        onTriggered: root.release()
    }

    property Connections audioServiceConnections: Connections {
        target: AudioService

        // Volume changes are represented by CenterIsland; do not open a floating OSD.
        function onOutputPresentationChanged(volume: real, muted: bool): void {
            void volume;
            void muted;
            void HyprlandService.focusedMonitorName;
        }
    }
}
