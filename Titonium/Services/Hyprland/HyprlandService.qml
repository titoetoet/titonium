pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Titonium.Core.Screens
import qs.Titonium.Services.Applications
import "WindowRegistry.js" as WindowRegistry
import "WindowRules.js" as WindowRules

Singleton {
    id: root
    property string focusedMonitorName: ""
    property var projectedWindows: Object.freeze([])
    property var recentWindowIds: Object.freeze([])
    property int workspaceWindowCount: 0

    readonly property var windows: root.projectedWindows
    readonly property int activeWorkspaceWindowCount: root.workspaceWindowCount

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

    function nativeWindowId(toplevel: var): string {
        const value = toplevel?.address || toplevel?.lastIpcObject?.address || "";
        return typeof value === "string" ? value.trim() : "";
    }

    function nativeAppId(toplevel: var): string {
        const value = toplevel?.wayland?.appId || toplevel?.lastIpcObject?.class
            || toplevel?.lastIpcObject?.initialClass || toplevel?.title || "";
        return typeof value === "string" ? value.trim() : "";
    }

    function recomputeWindows(): void {
        const source = Hyprland.toplevels.values || [];
        const descriptors = [];
        const nativeRecords = [];
        for (let index = 0; index < source.length; index++) {
            const toplevel = source[index];
            const appId = root.nativeAppId(toplevel);
            const window = WindowRules.descriptor({
                id: root.nativeWindowId(toplevel),
                appId: toplevel?.wayland?.appId || "",
                ipcClass: toplevel?.lastIpcObject?.class || "",
                initialClass: toplevel?.lastIpcObject?.initialClass || "",
                title: toplevel?.title || toplevel?.wayland?.title || "",
                icon: ApplicationService.iconForAppId(appId),
                active: toplevel?.activated === true || toplevel?.wayland?.activated === true,
                urgent: toplevel?.urgent === true,
                minimized: toplevel?.wayland?.minimized === true,
            });
            if (!window)
                continue;
            descriptors.push(window);
            nativeRecords.push({ id: window.id, native: toplevel });
        }
        WindowRegistry.replace(nativeRecords);
        root.recentWindowIds = WindowRules.mruIds(root.recentWindowIds, descriptors);
        root.projectedWindows = WindowRules.orderByIds(descriptors, root.recentWindowIds);

        const screen = ScreenPolicy.screens.length > 0 ? ScreenPolicy.screens[0] : null;
        const workspace = screen ? Hyprland.monitorFor(screen)?.activeWorkspace : null;
        root.workspaceWindowCount = workspace?.toplevels?.values.length || 0;
    }

    function activateWindow(id: string): bool {
        return WindowRegistry.activate(id, Hyprland.toplevels.values || []);
    }

    function closeWindow(id: string): bool {
        return WindowRegistry.close(id, Hyprland.toplevels.values || []);
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "focusedmon" || event.name === "focusedmonv2")
                root.focusedMonitorName = event.parse(2)[0] || "";
            root.recomputeWindows();
        }
        function onActiveToplevelChanged(): void { root.recomputeWindows(); }
        function onFocusedWorkspaceChanged(): void { root.recomputeWindows(); }
    }

    Component.onCompleted: {
        root.focusedMonitorName = Hyprland.focusedMonitor?.name || "";
        root.recomputeWindows();
    }
}
