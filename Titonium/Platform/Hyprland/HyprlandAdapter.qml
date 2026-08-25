pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Singleton {
    id: root

    property string observedWindowTitle: ""
    property string observedWindowClass: ""
    property string focusedMonitorName: ""
    readonly property var runningToplevels: {
        const source = ToplevelManager.toplevels?.values || [];
        return source.filter(toplevel => toplevel && toplevel.minimized !== true);
    }
    readonly property var hyprlandActiveToplevel: {
        if (Hyprland.activeToplevel)
            return Hyprland.activeToplevel;
        const toplevels = Hyprland.toplevels.values || [];
        for (let index = 0; index < toplevels.length; ++index) {
            if (toplevels[index]?.activated)
                return toplevels[index];
        }
        return null;
    }
    readonly property var waylandActiveToplevel: ToplevelManager.activeToplevel
    readonly property string activeWindowTitle: root.hyprlandActiveToplevel?.title
        || root.waylandActiveToplevel?.title
        || root.observedWindowTitle
    readonly property bool activeWindowValid: root.activeWindowTitle.length > 0
    readonly property string activeWindowClass: {
        if (root.hyprlandActiveToplevel) {
            const state = root.hyprlandActiveToplevel.lastIpcObject || {};
            return state.initialClass || state.class || root.observedWindowClass;
        }
        return root.waylandActiveToplevel?.appId || root.observedWindowClass;
    }

    function isToplevelActive(toplevel: var): bool {
        if (!toplevel)
            return false;
        if (toplevel.activated === true || ToplevelManager.activeToplevel === toplevel)
            return true;
        const appId = (toplevel.appId || "").trim().toLocaleLowerCase();
        const activeClass = root.activeWindowClass.trim().toLocaleLowerCase();
        return (appId.length > 0 && activeClass.length > 0
                && (appId === activeClass || appId.endsWith("." + activeClass)
                    || activeClass.endsWith("." + appId)))
            || (toplevel.title && root.activeWindowTitle
                && toplevel.title === root.activeWindowTitle);
    }

    function activateToplevel(toplevel: var): void {
        if (toplevel && typeof toplevel.activate === "function")
            toplevel.activate();
    }

    function monitorFor(screen: var): var {
        return screen ? Hyprland.monitorFor(screen) : null;
    }

    function activeWorkspaceId(screen: var): int {
        return root.monitorFor(screen)?.activeWorkspace?.id || 1;
    }

    function workspaceSnapshot(screen: var, count: int): var {
        const activeId = root.activeWorkspaceId(screen);
        const safeCount = Math.max(1, Math.min(10, count));
        const groupStart = Math.floor((Math.max(1, activeId) - 1) / safeCount) * safeCount + 1;
        const source = Hyprland.workspaces.values || [];
        const result = [];

        for (let offset = 0; offset < safeCount; ++offset) {
            const id = groupStart + offset;
            let occupied = false;
            let urgent = false;
            for (let index = 0; index < source.length; ++index) {
                const workspace = source[index];
                if (!workspace || workspace.id !== id)
                    continue;
                const state = workspace.lastIpcObject || {};
                occupied = Number(state.windows || 0) > 0
                    || (workspace.toplevels?.values?.length || 0) > 0;
                urgent = workspace.urgent === true;
                break;
            }
            result.push({
                "id": id,
                "active": id === activeId,
                "occupied": occupied,
                "urgent": urgent
            });
        }
        return result;
    }

    function activateWorkspace(workspaceId: int): void {
        if (workspaceId < 1)
            return;
        const source = Hyprland.workspaces.values || [];
        for (let index = 0; index < source.length; ++index) {
            const workspace = source[index];
            if (workspace && workspace.id === workspaceId && typeof workspace.activate === "function") {
                workspace.activate();
                return;
            }
        }
        Hyprland.dispatch(Hyprland.usingLua
            ? "hl.dsp.focus({ workspace = \"" + workspaceId + "\" })"
            : "workspace " + workspaceId);
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "focusedmon" || event.name === "focusedmonv2") {
                const monitorFields = event.parse(2);
                root.focusedMonitorName = monitorFields[0] || "";
                return;
            }
            if (event.name === "activewindow") {
                const fields = event.parse(2);
                root.observedWindowClass = fields[0] || "";
                root.observedWindowTitle = fields[1] || "";
            }
        }
    }
}
