pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces
QtObject {
    id: root

    readonly property bool active: SurfaceManager.ownerId.indexOf("audio:") === 0

    function ownerFor(screen: var): string {
        return screen?.name ? "audio:" + screen.name : "";
    }

    function open(screen: var): bool {
        const owner = root.ownerFor(screen);
        if (!owner)
            return false;
        return SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("AudioPopupSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
        }, screen);
    }

    function toggle(screen: var): bool {
        const owner = root.ownerFor(screen);
        if (!owner)
            return false;
        if (SurfaceManager.ownerId === root.ownerFor(screen))
            return SurfaceManager.close(owner);
        return root.open(screen);
    }

    function close(): bool {
        if (!root.active)
            return false;
        return SurfaceManager.close(SurfaceManager.ownerId);
    }
}
