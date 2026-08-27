pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Applications
import qs.Titonium.Services.Dock
import "DockRules.js" as DockRules

QtObject {
    id: root

    property var projectedItems: []
    property int workspaceWindowCount: 0
    property var nativeToplevelsByAppId: ({})
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

    function nativeToplevelsForAppId(appId: string): var {
        const key = root.appKey(appId);
        const current = root.nativeToplevelsByAppId[key] || [];
        const source = Hyprland.toplevels.values || [];
        const result = [];
        for (let index = 0; index < current.length; index++) {
            const candidate = current[index];
            if (source.indexOf(candidate) >= 0)
                result.push(candidate);
        }
        return result;
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
        return Hyprland.focusedWorkspace?.toplevels?.values.length || 0;
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
        root.nativeToplevelsByAppId = nativeById;
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

    function activateNative(toplevel: var, appId: string): bool {
        const target = toplevel?.wayland;
        if (!target || typeof target.activate !== "function") {
            root.warnMutation("activate", appId);
            return false;
        }
        target.activate();
        return true;
    }

    function closeNative(toplevel: var, appId: string): bool {
        const target = toplevel?.wayland;
        if (!target || typeof target.close !== "function") {
            root.warnMutation("close", appId);
            return false;
        }
        target.close();
        return true;
    }

    function activateOrLaunch(appId: string): bool {
        const toplevels = root.nativeToplevelsForAppId(appId);
        if (toplevels.length === 0)
            return root.launchNew(appId);
        const key = root.appKey(appId);
        let selectedIndex = root.cycleIndexesByAppId[key];
        if (selectedIndex === undefined) {
            selectedIndex = 0;
            for (let index = 0; index < toplevels.length; index++) {
                if (toplevels[index]?.activated === true) {
                    selectedIndex = index;
                    break;
                }
            }
        } else {
            selectedIndex = DockRules.nextCycleIndex(selectedIndex, toplevels.length);
        }
        const nextCycles = Object.assign({}, root.cycleIndexesByAppId);
        nextCycles[key] = selectedIndex;
        root.cycleIndexesByAppId = nextCycles;
        return root.activateNative(toplevels[selectedIndex], appId);
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
        const toplevels = root.nativeToplevelsForAppId(appId);
        if (toplevels.length === 0) {
            root.warnMutation("close", appId);
            return false;
        }
        let active = toplevels[0];
        for (let index = 0; index < toplevels.length; index++) {
            if (toplevels[index]?.activated === true) {
                active = toplevels[index];
                break;
            }
        }
        return root.closeNative(active, appId);
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
