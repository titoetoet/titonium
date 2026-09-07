pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Titonium.Core.Screens
import qs.Titonium.Services.Applications
import "WindowRegistry.js" as WindowRegistry
import "WindowRules.js" as WindowRules
import "WindowEventRules.js" as WindowEventRules
import "WorkspaceRules.js" as WorkspaceRules

Singleton {
    id: root
    property string focusedMonitorName: ""
    property var projectedWindows: Object.freeze([])
    property var recentWindowIds: Object.freeze([])
    property int workspaceWindowCount: 0
    property int policyActiveWorkspaceId: 1
    property int focusedWorkspaceIdValue: 1
    property bool focusInitialized: false
    property bool windowRefreshQueued: false

    readonly property var windows: root.projectedWindows
    readonly property string activeToplevelId: root.nativeWindowId(Hyprland.activeToplevel)
    readonly property var activeWindow: WindowRules.activeWindow(
        root.projectedWindows, root.activeToplevelId)
    readonly property int activeWorkspaceWindowCount: root.workspaceWindowCount

    function monitorFor(screen: var): var {
        if (!screen?.name)
            return null;
        const matched = WorkspaceRules.monitorByName(
            Hyprland.monitors.values || [], screen.name);
        if (matched)
            return matched;
        const fallback = Hyprland.monitorFor(screen);
        return fallback?.name === screen.name ? fallback : null;
    }
    function activeWorkspaceId(screen: var): int {
        return root.monitorFor(screen)?.activeWorkspace?.id || 1;
    }
    function focusedWorkspaceId(screen: var): int {
        return root.focusedWorkspaceIdValue || root.activeWorkspaceId(screen);
    }
    function workspaceSnapshot(screen: var, count: int, followFocus: bool): var {
        const activeId = followFocus
            ? root.focusedWorkspaceId(screen) : root.activeWorkspaceId(screen);
        return root.workspaceSnapshotForId(count, activeId);
    }
    function workspaceSnapshotForId(count: int, activeId: int): var {
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
    function bootstrapFocusedWorkspace(): void {
        if (root.focusInitialized)
            return;
        const monitors = Hyprland.monitors.values || [];
        const workspaceId = WorkspaceRules.focusedMonitorWorkspaceId(
            monitors, root.focusedMonitorName, 0)
            || WorkspaceRules.focusedWorkspaceId(monitors, 0);
        if (workspaceId <= 0)
            return;
        root.focusedWorkspaceIdValue = workspaceId;
        root.focusInitialized = true;
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

    function scheduleWindowRefresh(): void {
        if (root.windowRefreshQueued)
            return;
        root.windowRefreshQueued = true;
        Qt.callLater(root.flushWindowRefresh);
    }

    function flushWindowRefresh(): void {
        root.windowRefreshQueued = false;
        root.recomputeWindows();
    }

    function recomputeWindows(): void {
        const source = Hyprland.toplevels.values || [];
        const descriptors = [];
        const nativeRecords = [];
        for (let index = 0; index < source.length; index++) {
            const toplevel = source[index];
            const identity = ApplicationService.descriptorForWindowIdentity({
                appId: toplevel?.wayland?.appId || "",
                ipcClass: toplevel?.lastIpcObject?.class || "",
                initialClass: toplevel?.lastIpcObject?.initialClass || "",
                title: toplevel?.title || toplevel?.wayland?.title || ""
            });
            const window = WindowRules.descriptor({
                id: root.nativeWindowId(toplevel),
                appId: toplevel?.wayland?.appId || "",
                ipcClass: toplevel?.lastIpcObject?.class || "",
                initialClass: toplevel?.lastIpcObject?.initialClass || "",
                title: toplevel?.title || toplevel?.wayland?.title || "",
                resolvedAppId: identity.appId,
                icon: identity.icon,
                fallbackIcon: identity.fallbackIcon,
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
        root.policyActiveWorkspaceId = root.activeWorkspaceId(screen);
        root.workspaceWindowCount = WindowRules.workspaceWindowCount(
            descriptors, root.policyActiveWorkspaceId, screen?.name || "");
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
            const fields = event.parse(2);
            if (event.name === "focusedmon" || event.name === "focusedmonv2")
                root.focusedMonitorName = fields[0] || "";
            if (WindowEventRules.requiresProjection(event.name))
                root.scheduleWindowRefresh();
            const eventWorkspaceId = WorkspaceRules.focusedWorkspaceEventId(event.name, fields);
            if (eventWorkspaceId > 0) {
                root.focusedWorkspaceIdValue = eventWorkspaceId;
                root.focusInitialized = true;
            }
        }
        function onActiveToplevelChanged(): void { root.scheduleWindowRefresh(); }
        function onFocusedWorkspaceChanged(): void { root.scheduleWindowRefresh(); }
    }

    property Connections monitorModelConnections: Connections {
        target: Hyprland.monitors
        function onValuesChanged(): void {
            root.bootstrapFocusedWorkspace();
            root.scheduleWindowRefresh();
        }
    }

    // Native refresh replies can arrive after rawEvent. Observe the facts used by
    // projection so delayed title/class/workspace and Wayland changes are not lost.
    property Instantiator toplevelConnections: Instantiator {
        model: Hyprland.toplevels
        delegate: QtObject {
            id: toplevelObserver
            required property var modelData
            property Connections nativeConnection: Connections {
                target: toplevelObserver.modelData
                function onAddressChanged(): void { root.scheduleWindowRefresh(); }
                function onTitleChanged(): void { root.scheduleWindowRefresh(); }
                function onUrgentChanged(): void { root.scheduleWindowRefresh(); }
                function onWorkspaceChanged(): void { root.scheduleWindowRefresh(); }
                function onMonitorChanged(): void { root.scheduleWindowRefresh(); }
                function onLastIpcObjectChanged(): void { root.scheduleWindowRefresh(); }
                function onWaylandHandleChanged(): void { root.scheduleWindowRefresh(); }
            }
            property Connections waylandConnection: Connections {
                target: toplevelObserver.modelData?.wayland || null
                function onAppIdChanged(): void { root.scheduleWindowRefresh(); }
                function onTitleChanged(): void { root.scheduleWindowRefresh(); }
                function onMinimizedChanged(): void { root.scheduleWindowRefresh(); }
            }
        }
    }

    property Instantiator monitorConnections: Instantiator {
        model: Hyprland.monitors
        delegate: Connections {
            required property var modelData
            target: modelData
            function onActiveWorkspaceChanged(): void { root.scheduleWindowRefresh(); }
            function onLastIpcObjectChanged(): void { root.scheduleWindowRefresh(); }
        }
    }

    property Instantiator workspaceConnections: Instantiator {
        model: Hyprland.workspaces
        delegate: QtObject {
            id: workspaceObserver
            required property var modelData
            property Connections nativeConnection: Connections {
                target: workspaceObserver.modelData
                function onIdChanged(): void { root.scheduleWindowRefresh(); }
                function onMonitorChanged(): void { root.scheduleWindowRefresh(); }
                function onLastIpcObjectChanged(): void { root.scheduleWindowRefresh(); }
            }
            property Connections toplevelModelConnection: Connections {
                target: workspaceObserver.modelData?.toplevels || null
                function onValuesChanged(): void { root.scheduleWindowRefresh(); }
            }
        }
    }

    property Connections toplevelModelConnections: Connections {
        target: Hyprland.toplevels
        function onValuesChanged(): void { root.scheduleWindowRefresh(); }
    }
    property Connections workspaceModelConnections: Connections {
        target: Hyprland.workspaces
        function onValuesChanged(): void { root.scheduleWindowRefresh(); }
    }
    property Connections screenPolicyConnections: Connections {
        target: ScreenPolicy
        function onScreensChanged(): void { root.scheduleWindowRefresh(); }
    }
    property Connections applicationConnections: Connections {
        target: ApplicationService
        function onAllApplicationsChanged(): void { root.scheduleWindowRefresh(); }
    }

    Component.onCompleted: {
        root.focusedMonitorName = Hyprland.focusedMonitor?.name || "";
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
        Qt.callLater(root.bootstrapFocusedWorkspace);
        root.scheduleWindowRefresh();
    }
}
