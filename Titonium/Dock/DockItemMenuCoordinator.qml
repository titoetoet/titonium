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

    function menuItem(dockItem: var): var {
        if (!dockItem || typeof dockItem.appId !== "string" || dockItem.appId.trim().length === 0)
            return null;
        return {
            "appId": dockItem.appId,
            "name": typeof dockItem.name === "string" ? dockItem.name : dockItem.appId,
            "icon": typeof dockItem.icon === "string" ? dockItem.icon : "apps",
            "runningCount": Math.max(0, Number(dockItem.runningCount) || 0),
            "active": dockItem.active === true,
            "urgent": dockItem.urgent === true,
            "pinned": dockItem.pinned === true,
        };
    }

    function open(dockItem: var, invoker: var, screen: var): bool {
        const item = root.menuItem(dockItem);
        const owner = root.ownerFor(item?.appId || "", screen);
        if (!owner || !invoker)
            return false;
        if (SurfaceManager.active)
            SurfaceManager.close(SurfaceManager.ownerId);
        return SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("DockItemMenuSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
            "item": item,
            "invoker": invoker,
        }, screen);
    }

    function close(): bool {
        if (!root.active)
            return false;
        return SurfaceManager.close(SurfaceManager.ownerId);
    }
}
