pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Titonium.Core.Screens
import qs.Titonium.Services.Applications
import "WindowRegistry.js" as WindowRegistry
import "WindowRules.js" as WindowRules
import "WorkspaceRules.js" as WorkspaceRules

Singleton {
    id: root
    property string focusedMonitorName: ""
    property var projectedWindows: Object.freeze([])
    property var recentWindowIds: Object.freeze([])
    property int workspaceWindowCount: 0

    readonly property var windows: root.projectedWindows
    readonly property string activeToplevelId: root.nativeWindowId(Hyprland.activeToplevel)
    readonly property var activeWindow: WindowRules.activeWindow(
        root.projectedWindows, root.activeToplevelId)
    readonly property int activeWorkspaceWindowCount: root.workspaceWindowCount

    function monitorFor(screen: var): var { return screen ? Hyprland.monitorFor(screen) : null; }
    function activeWorkspaceId(screen: var): int {
        return root.monitorFor(screen)?.activeWorkspace?.id || 1;
    }
    function focusedWorkspaceId(screen: var): int {
        return Number(Hyprland.focusedWorkspace?.id)
            || root.activeWorkspaceId(screen);
    }
    function workspaceSnapshot(screen: var, count: int, followFocus: bool): var {
        const activeId = followFocus
            ? root.focusedWorkspaceId(screen) : root.activeWorkspaceId(screen);
        const source = Hyprland.workspaces.values || [];
        const facts = [];
        for (let index = 0; index < source.length; index++) {
            const workspace = source[index];
            if (!workspace)
                continue;
            const state = workspace.lastIpcObject || {};
            facts.push({
                id: workspace.id,
                occupied: Number(state.windows || 0) > 0
                    || (workspace.toplevels?.values?.length || 0) > 0,
                urgent: workspace.urgent === true,
            });
        }
        return WorkspaceRules.project(activeId, count, facts, root.windows);
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

    function workspaceIdFor(toplevel: var): int {
        const directId = Number(toplevel?.workspace?.id || 0);
        if (Number.isInteger(directId) && directId > 0)
            return directId;
        const ipcWorkspace = toplevel?.lastIpcObject?.workspace;
        const ipcId = Number(ipcWorkspace?.id || ipcWorkspace || 0);
        if (Number.isInteger(ipcId) && ipcId > 0)
            return ipcId;

        const targetId = root.nativeWindowId(toplevel);
        const workspaces = Hyprland.workspaces.values || [];
        for (let workspaceIndex = 0; workspaceIndex < workspaces.length; workspaceIndex++) {
            const workspace = workspaces[workspaceIndex];
            const candidates = workspace?.toplevels?.values || [];
            for (let windowIndex = 0; windowIndex < candidates.length; windowIndex++) {
                if (root.nativeWindowId(candidates[windowIndex]) === targetId)
                    return Number(workspace?.id || 0);
            }
        }
        if (toplevel?.activated === true || toplevel?.wayland?.activated === true)
            return Number(Hyprland.focusedWorkspace?.id || 0);
        return 0;
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
                urgent: toplevel?.urgent === true,
                minimized: toplevel?.wayland?.minimized === true,
                workspaceId: root.workspaceIdFor(toplevel),
                monitorName: toplevel?.workspace?.monitor?.name
                    || toplevel?.lastIpcObject?.monitor || "",
            }, root.activeToplevelId);
            if (!window)
                continue;
            descriptors.push(window);
            nativeRecords.push({ id: window.id, native: toplevel });
        }
        WindowRegistry.replace(nativeRecords);
        root.recentWindowIds = WindowRules.mruIds(root.recentWindowIds, descriptors);
        root.projectedWindows = WindowRules.orderByIds(descriptors, root.recentWindowIds);

        const screen = ScreenPolicy.screens.length > 0 ? ScreenPolicy.screens[0] : null;
        let activeId = 0;
        for (let index = 0; index < descriptors.length; index++) {
            const window = descriptors[index];
            if (window.active && window.workspaceId > 0) {
                activeId = window.workspaceId;
                break;
            }
        }
        if (activeId <= 0)
            activeId = root.activeWorkspaceId(screen);
        root.workspaceWindowCount = descriptors.filter(window => window.workspaceId === activeId
            && (!screen || !window.monitorName || window.monitorName === screen.name)).length;
    }

    function focusWindow(id: string): bool {
        const plan = WindowRules.focusPlan(id, root.windows);
        if (!plan)
            return false;
        const command = WindowRules.focusCommand(plan.id, Hyprland.usingLua);
        if (!command)
            return false;
        root.activateWorkspace(plan.workspaceId);
        Qt.callLater(() => Hyprland.dispatch(command));
        return true;
    }

    function activateWindow(id: string): bool {
        return root.focusWindow(id);
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
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        Qt.callLater(root.recomputeWindows);
    }
}
