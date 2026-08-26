pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property ShellScreen modelData
            readonly property bool ownsOsd: AudioOsdCoordinator.active
                && AudioOsdCoordinator.ownerScreenName === window.modelData.name

            screen: window.modelData
            visible: window.ownsOsd
            color: "transparent"
            implicitWidth: 320
            implicitHeight: 64
            aboveWindows: true
            exclusiveZone: 0
            WlrLayershell.namespace: "titonium-audio-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { bottom: true; left: false; right: false }
            mask: Region {}

            Loader {
                anchors.fill: parent
                active: window.visible
                sourceComponent: AudioOsd {
                    volume: AudioOsdCoordinator.volume
                    muted: AudioOsdCoordinator.muted
                }
            }
        }
    }
}
