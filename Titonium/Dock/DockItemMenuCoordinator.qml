pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Surfaces

QtObject {
    id: root

    readonly property bool active: SurfaceManager.ownerId.indexOf("dock-item-menu:") === 0

    function ownerFor(appId: string, screen: var): string {
        if (!appId || !screen?.name)
            return "";
        return "dock-item-menu:" + screen.name + ":" + appId;
    }

    function open(appId: string, invoker: var, screen: var): bool {
        const owner = root.ownerFor(appId, screen);
        if (!owner || !invoker)
            return false;
        if (SurfaceManager.active)
            SurfaceManager.close(SurfaceManager.ownerId);
        return SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("DockItemMenuSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
            "appId": appId,
            "invoker": invoker,
        }, screen);
    }

    function close(): bool {
        if (!root.active)
            return false;
        return SurfaceManager.close(SurfaceManager.ownerId);
    }
}
