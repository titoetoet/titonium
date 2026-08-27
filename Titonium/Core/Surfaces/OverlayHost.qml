pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Core.Screens
import qs.Titonium.Services.Hyprland

Scope {
    Variants {
        model: ScreenPolicy.screens

        PanelWindow {
            id: window
            required property ShellScreen modelData

            readonly property bool ownsSurface: SurfaceManager.active
                && SurfaceManager.screen === window.modelData

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
                && SurfaceManager.descriptor.keyboardFocus === "exclusive"
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }

            Loader {
                id: overlayLoader
                anchors.fill: parent
                active: window.ownsSurface && Boolean(SurfaceManager.descriptor.source)
                source: active ? SurfaceManager.descriptor.source : ""

                onLoaded: {
                    if (item && item.hasOwnProperty("descriptor"))
                        item.descriptor = SurfaceManager.descriptor;
                    if (item && item.hasOwnProperty("screen"))
                        item.screen = window.modelData;
                }
            }

            Binding {
                target: overlayLoader.item || null
                property: "descriptor"
                value: SurfaceManager.descriptor
                when: overlayLoader.item !== null && overlayLoader.item.hasOwnProperty("descriptor")
            }

            Binding {
                target: overlayLoader.item || null
                property: "screen"
                value: window.modelData
                when: overlayLoader.item !== null && overlayLoader.item.hasOwnProperty("screen")
            }

            Connections {
                target: HyprlandService
                function onFocusedMonitorNameChanged(): void {
                    if (!window.ownsSurface
                            || SurfaceManager.descriptor?.closeOnMonitorChange !== true)
                        return;
                    const focusedName = HyprlandService.focusedMonitorName;
                    if (focusedName.length > 0 && focusedName !== window.modelData.name)
                        SurfaceManager.close(SurfaceManager.ownerId);
                }
            }
        }
    }
}
