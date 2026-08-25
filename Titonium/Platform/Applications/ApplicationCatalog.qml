pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Foundation
import "ApplicationLaunch.js" as ApplicationLaunch

QtObject {
    id: root

    property var applications: []
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
                ? DesktopEntries.heuristicLookup(normalized.split(".").pop())
                : null);
    }

    function iconForAppId(appId: string): string {
        const entry = root.desktopEntryForAppId(appId);
        if (entry?.icon) {
            const entryIcon = root.iconFor(entry.icon);
            if (entryIcon)
                return entryIcon;
        }
        const normalized = (appId || "").trim().toLocaleLowerCase();
        const candidates = [appId, normalized];
        if (normalized.includes("."))
            candidates.push(normalized.split(".").pop());
        for (let index = 0; index < candidates.length; index++) {
            const candidate = candidates[index];
            if (candidate && Quickshell.hasThemeIcon(candidate))
                return Quickshell.iconPath(candidate);
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
            next.push({
                "id": entry.id,
                "name": entry.name,
                "nameLower": entry.name.toLocaleLowerCase(),
                "subtitle": entry.genericName || entry.comment || "",
                "searchText": (entry.name + " " + (entry.genericName || "") + " "
                    + (entry.comment || "")).toLocaleLowerCase(),
                "icon": root.iconFor(entry.icon),
                "categories": Array.isArray(entry.categories) ? entry.categories : []
            });
        }
        next.sort((left, right) => left.name.localeCompare(right.name));
        const signature = next.map(entry => entry.id).join("\n");
        root.applications = next;
        if (next.length > 0 && signature !== root.catalogSignature)
            Logger.info("applications", "catalog ready with " + next.length + " visible entries");
        root.catalogSignature = signature;
    }

    function launch(entryId: string): bool {
        const entry = DesktopEntries.byId(entryId);
        const result = ApplicationLaunch.request(entry);
        if (!result.accepted) {
            root.lastLaunchError = result.error;
            const detail = result.detail.length > 0 ? ": " + result.detail : "";
            Logger.warn("applications", entryId + ": " + result.error + detail);
            root.launchFailed(entryId, result.error);
            return false;
        }
        root.lastLaunchError = "";
        return true;
    }

    property Connections desktopEntryConnections: Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void { root.refresh(); }
    }

    Component.onCompleted: root.refresh()
}
