pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Platform.Applications
import "ApplicationVisibility.js" as ApplicationVisibility

QtObject {
    id: root

    readonly property var allApplications: ApplicationCatalog.applications
    readonly property var hiddenIds: ConfigStore.previewState.applications?.hiddenIds || []
    readonly property var visibleApplications:
        ApplicationVisibility.filterVisible(root.allApplications, root.hiddenIds)

    function isVisible(entryId: string): bool {
        return ApplicationVisibility.isVisible(root.hiddenIds, entryId);
    }

    function setVisible(entryId: string, visible: bool): bool {
        return ConfigStore.patch("applications.hiddenIds",
            ApplicationVisibility.setVisible(root.hiddenIds, entryId, visible));
    }
}
