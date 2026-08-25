pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation

QtObject {
    readonly property var sections: [
        { "id": "apps", "icon": "apps", "labelKey": "launcher.section.apps", "placement": "top" }
    ]

    function sourceFor(sectionId: string): url {
        if (sectionId === "apps")
            return Qt.resolvedUrl("AppsPage.qml");
        Logger.warn("launcher", "unknown section '" + sectionId + "'; falling back to apps");
        return Qt.resolvedUrl("AppsPage.qml");
    }
}
