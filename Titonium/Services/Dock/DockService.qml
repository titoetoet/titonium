pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Screens
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Dock
import "DockNativeRegistry.js" as DockNativeRegistry
import "DockRules.js" as DockRules

QtObject {
    id: root

    property var projectedItems: []
    property int workspaceWindowCount: 0
    property var operationRegistry: DockNativeRegistry.create()
    property var firstSeenIds: []
    property var cycleIndexesByAppId: ({})
    property var mutationWarningCounts: ({})

    readonly property var items: root.projectedItems
    readonly property int activeWorkspaceWindowCount: root.workspaceWindowCount

    function normalizedAppId(value: var): string {
        return typeof value === "string" ? value.trim() : "";
    }

    function appKey(appId: string): string {
        return root.normalizedAppId(appId).toLocaleLowerCase();
    }

    function entryForAppId(appId: string): var {
        return ApplicationService.desktopEntryForAppId(appId);
    }

    function descriptorForAppId(appId: string, entry: var): var {
        return {
            id: entry?.id || appId,
            name: entry?.name || ApplicationService.nameForAppId(appId),
            icon: ApplicationService.iconForAppId(appId),
        };
    }

    function nativeAppId(toplevel: var): string {
        return root.normalizedAppId(toplevel?.wayland?.appId
            || toplevel?.lastIpcObject?.class || toplevel?.title || "");
    }

    function rememberFirstSeen(appId: string): void {
        const key = root.appKey(appId);
        for (let index = 0; index < root.firstSeenIds.length; index++) {
            if (root.appKey(root.firstSeenIds[index]) === key)
                return;
        }
        root.firstSeenIds = root.firstSeenIds.concat([appId]);
    }

    function workspaceWindowTotal(): int {
        const screen = ScreenPolicy.screens.length > 0 ? ScreenPolicy.screens[0] : null;
        const workspace = screen ? Hyprland.monitorFor(screen)?.activeWorkspace : null;
        return workspace?.toplevels?.values.length || 0;
    }

    function recompute(): void {
        const source = Hyprland.toplevels.values || [];
        const nativeById = {};
        const groupsById = {};
        const entriesById = {};
        const order = [];
        for (let index = 0; index < source.length; index++) {
            const toplevel = source[index];
            const sourceId = root.nativeAppId(toplevel);
            if (!sourceId)
                continue;
            const entry = root.entryForAppId(sourceId);
            const appId = root.normalizedAppId(entry?.id || sourceId);
            const key = root.appKey(appId);
            if (!key)
                continue;
            if (!nativeById[key]) {
                nativeById[key] = [];
                groupsById[key] = { appId: appId, runningCount: 0, active: false, urgent: false };
                entriesById[appId] = root.descriptorForAppId(appId, entry);
                order.push(key);
                root.rememberFirstSeen(appId);
            }
            nativeById[key].push(toplevel);
            groupsById[key].runningCount += 1;
            groupsById[key].active = groupsById[key].active || toplevel?.activated === true;
            groupsById[key].urgent = groupsById[key].urgent || toplevel?.urgent === true;
        }
        const groups = [];
        for (let index = 0; index < order.length; index++)
            groups.push(groupsById[order[index]]);
        root.operationRegistry.replace(nativeById);
        root.workspaceWindowCount = root.workspaceWindowTotal();
        root.projectedItems = DockRules.mergeItems(
            DockStore.pinnedIds, groups, entriesById, root.firstSeenIds);
    }

    function warnMutation(action: string, appId: string): void {
        const key = action + ":" + root.appKey(appId);
        const count = root.mutationWarningCounts[key] || 0;
        if (count >= 3)
            return;
        const next = Object.assign({}, root.mutationWarningCounts);
        next[key] = count + 1;
        root.mutationWarningCounts = next;
        Logger.warn("dock", action + " ignored for unavailable application " + appId);
    }

    function activateOrLaunch(appId: string): bool {
        const key = root.appKey(appId);
        const result = root.operationRegistry.activate(
            key, Hyprland.toplevels.values || [], root.cycleIndexesByAppId[key]);
        if (!result.available)
            return root.launchNew(appId);
        if (!result.success) {
            root.warnMutation("activate", appId);
            return false;
        }
        const nextCycles = Object.assign({}, root.cycleIndexesByAppId);
        nextCycles[key] = result.selectedIndex;
        root.cycleIndexesByAppId = nextCycles;
        return true;
    }

    function launchNew(appId: string): bool {
        const entry = root.entryForAppId(appId);
        if (!entry?.id) {
            root.warnMutation("launch", appId);
            return false;
        }
        return ApplicationService.launch(entry.id);
    }

    function closeActive(appId: string): bool {
        const result = root.operationRegistry.closeActive(
            root.appKey(appId), Hyprland.toplevels.values || []);
        if (!result.available) {
            root.warnMutation("close", appId);
            return false;
        }
        if (!result.success)
            root.warnMutation("close", appId);
        return result.success;
    }

    function togglePin(appId: string): bool {
        return DockStore.togglePin(appId);
    }

    function snapshot(): string {
        return JSON.stringify({
            items: root.items,
            activeWorkspaceWindowCount: root.activeWorkspaceWindowCount,
        });
    }

    property Connections hyprlandConnections: Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void { root.recompute(); }
        function onActiveToplevelChanged(): void { root.recompute(); }
        function onFocusedWorkspaceChanged(): void { root.recompute(); }
    }

    property Connections dockStoreConnections: Connections {
        target: DockStore
        function onPinnedIdsChanged(): void { root.recompute(); }
    }

    property Connections applicationConnections: Connections {
        target: ApplicationService
        function onAllApplicationsChanged(): void { root.recompute(); }
    }

    Component.onCompleted: root.recompute()
}
