pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.Hyprland
import "WindowSwitcherRules.js" as WindowSwitcherRules

QtObject {
    id: root

    property var orderedWindows: Object.freeze([])
    property var recentIds: Object.freeze([])
    property string selectedId: ""

    readonly property bool active: SurfaceManager.ownerId.indexOf("window-switcher:") === 0
    readonly property var windows: root.orderedWindows

    function refresh(): void {
        root.recentIds = WindowSwitcherRules.mruIds(
            root.recentIds, HyprlandService.windows);
        root.orderedWindows = WindowSwitcherRules.orderedWindows(
            HyprlandService.windows, root.recentIds);
        if (root.windows.length === 0) {
            if (root.active)
                root.cancel();
            else
                root.selectedId = "";
            return;
        }
        if (root.active)
            root.selectedId = WindowSwitcherRules.reconcileSelection(
                root.windows, root.selectedId);
    }

    function begin(direction: string): bool {
        root.refresh();
        if (root.windows.length === 0)
            return false;
        const screen = ScreenRouter.screenForName(HyprlandService.focusedMonitorName);
        if (!screen)
            return false;
        root.selectedId = WindowSwitcherRules.beginSelection(root.windows, direction);
        const owner = "window-switcher:" + screen.name;
        const opened = SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("../../Overlays/WindowSwitcher/WindowSwitcherSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
        }, screen);
        if (!opened)
            root.selectedId = "";
        return opened;
    }

    function move(offset: int): bool {
        if (!root.active)
            return root.begin(offset < 0 ? "previous" : "next");
        root.refresh();
        if (!root.active || root.windows.length === 0)
            return false;
        root.selectedId = WindowSwitcherRules.moveSelection(
            root.windows, root.selectedId, offset);
        return root.selectedId.length > 0;
    }

    function next(): bool {
        return root.move(1);
    }

    function previous(): bool {
        return root.move(-1);
    }

    function select(id: string): bool {
        if (!root.active)
            return false;
        const resolved = WindowSwitcherRules.reconcileSelection(root.windows, id);
        if (resolved !== id)
            return false;
        root.selectedId = resolved;
        return true;
    }

    function accept(): bool {
        if (!root.active)
            return false;
        root.refresh();
        const id = root.selectedId;
        if (!id) {
            root.cancel();
            return false;
        }
        root.cancel();
        return HyprlandService.focusWindow(id);
    }

    function cancel(): bool {
        const wasActive = root.active;
        const owner = wasActive ? SurfaceManager.ownerId : "";
        root.selectedId = "";
        return wasActive ? SurfaceManager.close(owner) : false;
    }

    function snapshot(): string {
        return JSON.stringify({
            active: root.active,
            selectedId: root.selectedId,
            windows: root.windows,
        });
    }

    property Connections hyprlandConnections: Connections {
        target: HyprlandService
        function onWindowsChanged(): void { root.refresh(); }
    }

    property Connections surfaceConnections: Connections {
        target: SurfaceManager
        function onOwnerIdChanged(): void {
            if (!root.active)
                root.selectedId = "";
        }
    }

    Component.onCompleted: root.refresh()
}
