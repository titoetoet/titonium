pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Audio
import qs.Titonium.Services.Hyprland

QtObject {
    id: root

    property bool activeState: false
    property string ownerScreenNameState: ""
    property real volumeState: 0
    property bool mutedState: false

    readonly property bool active: root.activeState
    readonly property string ownerScreenName: root.ownerScreenNameState
    readonly property real volume: root.volumeState
    readonly property bool muted: root.mutedState

    function show(screenName: string, volume: real, muted: bool): bool {
        if (screenName.length === 0)
            return false;
        root.ownerScreenNameState = screenName;
        root.volumeState = volume;
        root.mutedState = muted;
        root.activeState = true;
        hideTimer.restart();
        return true;
    }

    function hide(): bool {
        if (!root.active)
            return false;
        root.activeState = false;
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

    property Connections audioServiceConnections: Connections {
        target: AudioService

        function onOutputPresentationChanged(volume: real, muted: bool): void {
            root.show(HyprlandService.focusedMonitorName, volume, muted);
        }
    }
}
