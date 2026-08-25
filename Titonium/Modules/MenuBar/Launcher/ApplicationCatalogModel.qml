pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation
import qs.Titonium.Platform.Applications

QtObject {
    id: root

    property string query: ""
    property string category: ConfigStore.previewState.modules?.launcher?.defaultCategory || "all"
    readonly property var applications: ApplicationCatalog.applications
    readonly property int historyRevision: LauncherHistoryStore.revision
    readonly property var filteredApplications: root.filterApplications()
    readonly property int pageSize: 24
    readonly property var pages: root.buildPages()

    function categoryMatches(app: var): bool {
        if (root.category === "all")
            return true;
        if (root.category === "recent")
            return LauncherHistoryStore.recentIds.indexOf(app.id) >= 0;
        const categories = (app.categories || []).join(" ").toLocaleLowerCase();
        if (root.category === "internet")
            return /network|webbrowser|email|chat|internet|remote|messaging/.test(categories);
        if (root.category === "development")
            return /development|ide|editor|programming|debugger|git/.test(categories);
        if (root.category === "media")
            return /audio|video|graphics|player|music|image|photography/.test(categories);
        if (root.category === "system")
            return /system|settings|terminal|monitor|package|hardware|utility|accessories/.test(categories);
        return true;
    }

    function filterApplications(): var {
        const normalizedQuery = root.query.trim().toLocaleLowerCase();
        // Reading revision makes usage ordering and Recent recompute after state updates.
        if (root.historyRevision < 0)
            return [];
        const searchAll = normalizedQuery.length > 0;
        const result = root.applications.filter(app => (searchAll || root.categoryMatches(app))
            && (normalizedQuery.length === 0 || app.searchText.includes(normalizedQuery)));
        if (root.category === "recent") {
            const order = LauncherHistoryStore.recentIds;
            result.sort((left, right) => order.indexOf(left.id) - order.indexOf(right.id));
        } else if (root.category === "all" && !searchAll) {
            const recentOrder = LauncherHistoryStore.recentIds;
            const mostUsed = result.filter(app => LauncherHistoryStore.launchCount(app.id) > 0)
                .sort((left, right) => {
                    const countDifference = LauncherHistoryStore.launchCount(right.id)
                        - LauncherHistoryStore.launchCount(left.id);
                    if (countDifference !== 0)
                        return countDifference;
                    const leftRecentIndex = recentOrder.indexOf(left.id);
                    const rightRecentIndex = recentOrder.indexOf(right.id);
                    return (leftRecentIndex < 0 ? Number.MAX_SAFE_INTEGER : leftRecentIndex)
                        - (rightRecentIndex < 0 ? Number.MAX_SAFE_INTEGER : rightRecentIndex);
                })
                .slice(0, 6);
            const promoted = {};
            mostUsed.forEach(app => promoted[app.id] = true);
            return mostUsed.concat(result.filter(app => !promoted[app.id])
                .sort((left, right) => left.name.localeCompare(right.name)));
        }
        return result;
    }

    function buildPages(): var {
        const result = [];
        for (let index = 0; index < root.filteredApplications.length; index += root.pageSize)
            result.push(root.filteredApplications.slice(index, index + root.pageSize));
        return result.length > 0 ? result : [[]];
    }

    function launch(app: var): bool {
        if (!app?.id || !ApplicationCatalog.launch(app.id))
            return false;
        LauncherHistoryStore.recordLaunch(app.id);
        return true;
    }
}
