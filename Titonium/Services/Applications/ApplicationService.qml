pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Core.Runtime
import "ApplicationLaunch.js" as ApplicationLaunch
import "ApplicationProjection.js" as ApplicationProjection
import "Visibility.js" as Visibility

QtObject {
    id: root

    property var allApplications: []
    readonly property var visibleApplications:
        Visibility.filterVisible(root.allApplications, Preferences.hiddenApplicationIds)
    property string catalogSignature: ""
    property string lastLaunchError: ""
    signal launchFailed(string entryId, string error)

    function iconFor(iconName: string): string {
        if (!iconName)
            return "";
        if (iconName.indexOf("/") === 0)
            return "file://" + iconName;
        return Quickshell.hasThemeIcon(iconName) ? Quickshell.iconPath(iconName) : "";
    }

    function desktopEntryForAppId(appId: string): var {
        if (!appId)
            return null;
        const normalized = appId.trim().toLocaleLowerCase();
        return DesktopEntries.heuristicLookup(appId)
            || DesktopEntries.heuristicLookup(normalized)
            || (normalized.includes(".")
                ? DesktopEntries.heuristicLookup(normalized.split(".").pop()) : null);
    }

    function iconForAppId(appId: string): string {
        const entry = root.desktopEntryForAppId(appId);
        if (entry?.icon) {
            const icon = root.iconFor(entry.icon);
            if (icon)
                return icon;
        }
        const normalized = (appId || "").trim().toLocaleLowerCase();
        const candidates = [appId, normalized];
        if (normalized.includes("."))
            candidates.push(normalized.split(".").pop());
        for (let index = 0; index < candidates.length; index++) {
            if (candidates[index] && Quickshell.hasThemeIcon(candidates[index]))
                return Quickshell.iconPath(candidates[index]);
        }
        return "";
    }

    function nameForAppId(appId: string): string {
        return root.desktopEntryForAppId(appId)?.name || appId || "Application";
    }

    function refresh(): void {
        const rawEntries = DesktopEntries.applications.values || [];
        const seen = {};
        const next = [];
        for (let index = 0; index < rawEntries.length; index++) {
            const entry = rawEntries[index];
            if (!entry || entry.noDisplay || !entry.id || !entry.name || seen[entry.id])
                continue;
            seen[entry.id] = true;
            next.push({ id: entry.id, name: entry.name,
                nameLower: entry.name.toLocaleLowerCase(),
                subtitle: entry.genericName || entry.comment || "",
                searchText: (entry.name + " " + (entry.genericName || "") + " "
                    + (entry.comment || "")).toLocaleLowerCase(),
                icon: root.iconFor(entry.icon),
                categories: ApplicationProjection.categoryNames(entry.categories) });
        }
        next.sort((left, right) => left.name.localeCompare(right.name));
        const signature = next.map(entry => entry.id).join("\n");
        root.allApplications = next;
        if (next.length > 0 && signature !== root.catalogSignature)
            Logger.info("applications", "catalog ready with " + next.length + " entries");
        root.catalogSignature = signature;
    }

    function launch(entryId: string): bool {
        const result = ApplicationLaunch.request(DesktopEntries.byId(entryId));
        if (!result.accepted) {
            root.lastLaunchError = result.error;
            Logger.warn("applications", entryId + ": " + result.error);
            root.launchFailed(entryId, result.error);
            return false;
        }
        root.lastLaunchError = "";
        return true;
    }

    function isVisible(entryId: string): bool {
        return Visibility.isVisible(Preferences.hiddenApplicationIds, entryId);
    }

    property Connections desktopEntryConnections: Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void { root.refresh(); }
    }
    Component.onCompleted: root.refresh()
}
