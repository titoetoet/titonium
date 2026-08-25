pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var recentIds: []
    property var launchCounts: ({})
    property int revision: 0

    readonly property int maximumRecent: 24

    function uniqueStrings(values: var, limit: int): var {
        if (!Array.isArray(values))
            return [];
        const seen = {};
        const result = [];
        for (let index = 0; index < values.length && result.length < limit; index++) {
            const value = values[index];
            if (typeof value !== "string" || value.length === 0 || seen[value])
                continue;
            seen[value] = true;
            result.push(value);
        }
        return result;
    }

    function initialize(): void {
        const text = historyFile.text();
        if (text && text.trim().length > 0) {
            try {
                const document = JSON.parse(text);
                if (document.schemaVersion === 1 || document.schemaVersion === 2) {
                    root.recentIds = root.uniqueStrings(document.recentIds, root.maximumRecent);
                    if (document.schemaVersion === 1) {
                        const seededCounts = {};
                        root.recentIds.forEach(entryId => seededCounts[entryId] = 1);
                        root.launchCounts = seededCounts;
                    } else if (document.launchCounts
                            && typeof document.launchCounts === "object"
                            && !Array.isArray(document.launchCounts)) {
                        const counts = {};
                        Object.keys(document.launchCounts).forEach(entryId => {
                            const count = document.launchCounts[entryId];
                            if (entryId.length > 0 && Number.isInteger(count) && count > 0)
                                counts[entryId] = count;
                        });
                        root.launchCounts = counts;
                    }
                }
            } catch (error) {
                Logger.warn("launcher", "history state rejected: " + error);
            }
        }
        root.revision++;
    }

    function persist(): void {
        historyFile.setText(JSON.stringify({
            "schemaVersion": 2,
            "recentIds": root.recentIds,
            "launchCounts": root.launchCounts
        }, null, 2) + "\n");
        root.revision++;
    }

    function launchCount(entryId: string): int {
        const count = root.launchCounts[entryId];
        return Number.isInteger(count) && count > 0 ? count : 0;
    }

    function recordLaunch(entryId: string): void {
        if (!entryId)
            return;
        const next = root.recentIds.filter(value => value !== entryId);
        next.unshift(entryId);
        root.recentIds = root.uniqueStrings(next, root.maximumRecent);
        const counts = Object.assign({}, root.launchCounts);
        counts[entryId] = root.launchCount(entryId) + 1;
        root.launchCounts = counts;
        root.persist();
    }

    Component.onCompleted: root.initialize()

    property FileView historyFile: FileView {
        path: Quickshell.statePath("launcher-history.json")
        preload: false
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onSaveFailed: error => Logger.error("launcher", "history save failed: " + error)
    }
}
