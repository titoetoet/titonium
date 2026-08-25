pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Platform.Applications

QtObject {
    id: root

    property string query: ""
    property string category: "all"
    readonly property var applications: ApplicationCatalog.applications
    readonly property var filteredApplications: root.filterApplications()
    readonly property int visibleLimit: 24
    readonly property var visibleApplications: root.filteredApplications.slice(0, root.visibleLimit)

    function categoryMatches(app: var): bool {
        if (root.category === "all")
            return true;
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
        return root.applications.filter(app => root.categoryMatches(app)
            && (normalizedQuery.length === 0 || app.searchText.includes(normalizedQuery)));
    }

    function launch(app: var): bool {
        return app && app.id ? ApplicationCatalog.launch(app.id) : false;
    }
}
