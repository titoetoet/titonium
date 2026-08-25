pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Foundation
import qs.Titonium.Platform.Hyprland

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
            implicitWidth: window.modelData.width
            implicitHeight: window.modelData.height
            aboveWindows: true
            WlrLayershell.namespace: "titonium-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: window.ownsSurface
                && SurfaceCoordinator.descriptor.keyboardFocus === "exclusive"
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None

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

            Binding {
                target: overlayLoader.item || null
                property: "descriptor"
                value: SurfaceCoordinator.descriptor
                when: overlayLoader.item !== null && overlayLoader.item.hasOwnProperty("descriptor")
            }

            Binding {
                target: overlayLoader.item || null
                property: "screen"
                value: window.modelData
                when: overlayLoader.item !== null && overlayLoader.item.hasOwnProperty("screen")
            }

            Connections {
                target: HyprlandAdapter

                function onFocusedMonitorNameChanged(): void {
                    if (!window.ownsSurface
                            || SurfaceCoordinator.descriptor?.closeOnMonitorChange !== true)
                        return;
                    const focusedName = HyprlandAdapter.focusedMonitorName;
                    if (focusedName.length > 0 && focusedName !== window.modelData.name)
                        SurfaceCoordinator.close(SurfaceCoordinator.ownerId);
                }
            }
        }
    }
}
