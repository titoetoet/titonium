pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Dock
import qs.Titonium.Services.Hyprland
import "DockRules.js" as DockRules

QtObject {
    id: root

    property var projectedItems: []
    property int workspaceWindowCount: 0
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

    function rememberFirstSeen(appId: string): void {
        const key = root.appKey(appId);
        for (let index = 0; index < root.firstSeenIds.length; index++) {
            if (root.appKey(root.firstSeenIds[index]) === key)
                return;
        }
        root.firstSeenIds = root.firstSeenIds.concat([appId]);
    }

    function windowsForAppId(appId: string): var {
        const key = root.appKey(appId);
        return HyprlandService.windows.filter(window => root.appKey(window?.appId) === key);
    }

    function recompute(): void {
        const source = HyprlandService.windows;
        const groupsById = {};
        const entriesById = {};
        const order = [];
        for (let index = 0; index < source.length; index++) {
            const window = source[index];
            const sourceId = root.normalizedAppId(window?.appId);
            if (!sourceId)
                continue;
            const entry = root.entryForAppId(sourceId);
            const appId = root.normalizedAppId(entry?.id || sourceId);
            const key = root.appKey(appId);
            if (!key)
                continue;
            if (!groupsById[key]) {
                groupsById[key] = { appId: appId, runningCount: 0, active: false, urgent: false };
                entriesById[appId] = root.descriptorForAppId(appId, entry);
                order.push(key);
                root.rememberFirstSeen(appId);
            }
            groupsById[key].runningCount += 1;
            groupsById[key].active = groupsById[key].active || window?.active === true;
            groupsById[key].urgent = groupsById[key].urgent || window?.urgent === true;
        }
        const groups = [];
        for (let index = 0; index < order.length; index++)
            groups.push(groupsById[order[index]]);
        root.workspaceWindowCount = HyprlandService.activeWorkspaceWindowCount;
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
        const windows = root.windowsForAppId(appId);
        if (windows.length === 0)
            return root.launchNew(appId);
        const previousIndex = root.cycleIndexesByAppId[key];
        let selectedIndex = Number.isInteger(previousIndex) && previousIndex >= 0
            && previousIndex < windows.length ? (previousIndex + 1) % windows.length : 0;
        if (!Number.isInteger(previousIndex)) {
            for (let index = 0; index < windows.length; index++) {
                if (windows[index]?.active === true) {
                    selectedIndex = index;
                    break;
                }
            }
        }
        if (!HyprlandService.activateWindow(windows[selectedIndex].id)) {
            root.warnMutation("activate", appId);
            return false;
        }
        const nextCycles = Object.assign({}, root.cycleIndexesByAppId);
        nextCycles[key] = selectedIndex;
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
        const windows = root.windowsForAppId(appId);
        if (windows.length === 0) {
            root.warnMutation("close", appId);
            return false;
        }
        let selected = windows[0];
        for (let index = 0; index < windows.length; index++) {
            if (windows[index]?.active === true) {
                selected = windows[index];
                break;
            }
        }
        const success = HyprlandService.closeWindow(selected.id);
        if (!success)
            root.warnMutation("close", appId);
        return success;
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
        target: HyprlandService
        function onWindowsChanged(): void { root.recompute(); }
        function onActiveWorkspaceWindowCountChanged(): void { root.recompute(); }
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
