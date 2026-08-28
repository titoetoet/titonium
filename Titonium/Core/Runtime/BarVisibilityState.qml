pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    readonly property bool pinned: Preferences.bar.autoHide !== true

    function togglePinned(): bool {
        const nextAutoHide = root.pinned;
        return Preferences.previewActive
            ? Preferences.patch("modules.bar.autoHide", nextAutoHide)
            : Preferences.commitPatch("modules.bar.autoHide", nextAutoHide);
    }
}
