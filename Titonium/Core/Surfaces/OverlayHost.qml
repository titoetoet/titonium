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
            readonly property bool ownsOverlaySurface: window.ownsSurface
                && SurfaceManager.descriptor.barConnected !== true
            readonly property bool wantsInteractiveFocus: window.ownsOverlaySurface
                && SurfaceManager.descriptor.keyboardFocus === "exclusive"
            readonly property string logicalFocusOwnerId: window.wantsInteractiveFocus
                ? "overlay:" + SurfaceManager.ownerId : ""
            property string focusOwnerId: ""
            property string focusLease: ""
            property string diagnosticFocusOwnerId: ""
            readonly property bool effectiveInteractiveFocus: window.wantsInteractiveFocus
                && FocusArbiter.granted(window.focusOwnerId, window.focusLease)

            function syncInteractiveFocus(): void {
                if (window.wantsInteractiveFocus && window.logicalFocusOwnerId)
                    window.focusOwnerId = window.logicalFocusOwnerId;
                if (window.focusOwnerId && window.focusLease)
                    FocusArbiter.request(window.focusOwnerId, window.focusLease,
                        window.wantsInteractiveFocus);
            }

            onWantsInteractiveFocusChanged: window.syncInteractiveFocus()
            onLogicalFocusOwnerIdChanged: window.syncInteractiveFocus()
            onEffectiveInteractiveFocusChanged: {
                if (window.effectiveInteractiveFocus) {
                    window.diagnosticFocusOwnerId = window.focusOwnerId;
                    FocusDiagnostics.observe(window.diagnosticFocusOwnerId, true,
                        { mode: "overlay", focusPolicy: "exclusive" });
                } else if (window.diagnosticFocusOwnerId) {
                    FocusDiagnostics.observe(window.diagnosticFocusOwnerId, false,
                        { mode: "closed", focusPolicy: "exclusive" });
                    window.diagnosticFocusOwnerId = "";
                }
            }
            Component.onCompleted: {
                window.focusLease = FocusArbiter.newLease("overlay");
                window.syncInteractiveFocus();
            }

            screen: window.modelData
            visible: window.ownsOverlaySurface
            color: "transparent"
            implicitWidth: window.modelData.width
            implicitHeight: window.modelData.height
            aboveWindows: true
            WlrLayershell.namespace: "titonium-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: window.ownsOverlaySurface
                && SurfaceManager.descriptor.keyboardFocus === "exclusive"
                && FocusArbiter.granted(window.focusOwnerId, window.focusLease)
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }
            readonly property var overlayInputRegions:
                SurfaceInputRegions.regionsFor(window.modelData)
            mask: Region {
                width: window.ownsOverlaySurface ? window.modelData.width : 0
                height: window.ownsOverlaySurface ? window.modelData.height : 0

                Region {
                    x: window.overlayInputRegions.body.x
                    y: window.overlayInputRegions.body.y
                    width: window.overlayInputRegions.body.width
                    height: window.overlayInputRegions.body.height
                    intersection: Intersection.Subtract
                }

                Region {
                    x: window.overlayInputRegions.edge.x
                    y: window.overlayInputRegions.edge.y
                    width: window.overlayInputRegions.edge.width
                    height: window.overlayInputRegions.edge.height
                    intersection: Intersection.Subtract
                }
            }

            Loader {
                id: overlayLoader
                property string loadOwnerId: ""
                property var loadDescriptor: null
                property var loadScreen: null

                function captureSnapshot(): void {
                    if (!window.ownsOverlaySurface)
                        return;
                    loadOwnerId = SurfaceManager.ownerId;
                    loadDescriptor = SurfaceManager.descriptor;
                    loadScreen = SurfaceManager.screen;
                }

                function clearSnapshot(): void {
                    loadOwnerId = "";
                    loadDescriptor = null;
                    loadScreen = null;
                }

                function releaseSnapshot(): void {
                    SurfaceManager.closeOwned(loadOwnerId, loadDescriptor, loadScreen);
                    clearSnapshot();
                }

                anchors.fill: parent
                active: window.ownsSurface && Boolean(SurfaceManager.descriptor.source)
                    && SurfaceManager.descriptor.barConnected !== true
                source: active ? SurfaceManager.descriptor.source : ""

                onLoaded: {
                    if (item && item.hasOwnProperty("descriptor"))
                        item.descriptor = SurfaceManager.descriptor;
                    if (item && item.hasOwnProperty("screen"))
                        item.screen = window.modelData;
                }
                onStatusChanged: {
                    if (status === Loader.Loading)
                        captureSnapshot();
                    else if (status === Loader.Error)
                        releaseSnapshot();
                }
                onActiveChanged: {
                    if (active)
                        captureSnapshot();
                    else
                        clearSnapshot();
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

            Component.onDestruction: {
                if (window.focusOwnerId) {
                    FocusArbiter.withdraw(window.focusOwnerId, window.focusLease);
                    if (window.diagnosticFocusOwnerId)
                        FocusDiagnostics.observe(window.diagnosticFocusOwnerId, false,
                            { mode: "destroyed" });
                }
                const ownerId = SurfaceManager.ownerId;
                const descriptor = SurfaceManager.descriptor;
                const screen = SurfaceManager.screen;
                overlayLoader.releaseSnapshot();
                if (screen === window.modelData
                        && descriptor?.barConnected !== true)
                    SurfaceManager.closeOwned(ownerId, descriptor, screen);
            }
        }
    }
}
