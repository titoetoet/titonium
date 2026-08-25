pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Foundation

QtObject {
    id: root

    property var applications: []

    function iconFor(iconName: string): string {
        if (!iconName)
            return "";
        if (iconName.indexOf("/") === 0)
            return "file://" + iconName;
        return Quickshell.hasThemeIcon(iconName) ? Quickshell.iconPath(iconName) : "";
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
                "categories": entry.categories || []
            });
        }
        next.sort((left, right) => left.name.localeCompare(right.name));
        root.applications = next;
        if (next.length > 0)
            Logger.info("applications", "catalog ready with " + next.length + " visible entries");
    }

    function launch(entryId: string): bool {
        const entry = DesktopEntries.byId(entryId);
        if (!entry) {
            Logger.warn("applications", "desktop entry disappeared: " + entryId);
            return false;
        }
        entry.execute();
        return true;
    }

    property Connections desktopEntryConnections: Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void { root.refresh(); }
    }

    Component.onCompleted: root.refresh()
}
