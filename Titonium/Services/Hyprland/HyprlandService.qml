pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root
    property string focusedMonitorName: ""

    function monitorFor(screen: var): var { return screen ? Hyprland.monitorFor(screen) : null; }
    function activeWorkspaceId(screen: var): int {
        return root.monitorFor(screen)?.activeWorkspace?.id || 1;
    }
    function workspaceSnapshot(screen: var, count: int): var {
        const activeId = root.activeWorkspaceId(screen);
        const safeCount = Math.max(1, Math.min(10, count));
        const groupStart = Math.floor((Math.max(1, activeId) - 1) / safeCount) * safeCount + 1;
        const source = Hyprland.workspaces.values || [], result = [];
        for (let offset = 0; offset < safeCount; offset++) {
            const id = groupStart + offset;
            let occupied = false, urgent = false;
            for (let index = 0; index < source.length; index++) {
                const workspace = source[index];
                if (!workspace || workspace.id !== id) continue;
                const state = workspace.lastIpcObject || {};
                occupied = Number(state.windows || 0) > 0
                    || (workspace.toplevels?.values?.length || 0) > 0;
                urgent = workspace.urgent === true;
                break;
            }
            result.push({ id: id, active: id === activeId, occupied: occupied, urgent: urgent });
        }
        return result;
    }
    function activateWorkspace(workspaceId: int): void {
        if (workspaceId < 1) return;
        const source = Hyprland.workspaces.values || [];
        for (let index = 0; index < source.length; index++) {
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
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "focusedmon" || event.name === "focusedmonv2")
                root.focusedMonitorName = event.parse(2)[0] || "";
        }
    }
}
