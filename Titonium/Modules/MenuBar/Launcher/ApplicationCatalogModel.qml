pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Platform.Applications
import "LauncherLayout.js" as LauncherLayout

QtObject {
    id: root

    property int pageCapacity: 1
    readonly property var applications: ApplicationCatalog.applications
    readonly property var pages: LauncherLayout.pages(root.applications, root.pageCapacity)

    function launch(app: var): bool {
        return Boolean(app?.id && ApplicationCatalog.launch(app.id));
    }
}
