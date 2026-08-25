pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Foundation

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property ShellScreen modelData

            readonly property bool ownsSurface: SurfaceCoordinator.active
                && SurfaceCoordinator.screen === window.modelData

            screen: window.modelData
            visible: window.ownsSurface
            color: "transparent"
            aboveWindows: true
            WlrLayershell.namespace: "titonium-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Loader {
                id: overlayLoader
                anchors.fill: parent
                active: window.ownsSurface && Boolean(SurfaceCoordinator.descriptor.source)
                source: active ? SurfaceCoordinator.descriptor.source : ""

                onLoaded: {
                    if (overlayLoader.item && overlayLoader.item.hasOwnProperty("descriptor"))
                        overlayLoader.item.descriptor = SurfaceCoordinator.descriptor;
                    if (overlayLoader.item && overlayLoader.item.hasOwnProperty("screen"))
                        overlayLoader.item.screen = window.modelData;
                }
            }
        }
    }
}
