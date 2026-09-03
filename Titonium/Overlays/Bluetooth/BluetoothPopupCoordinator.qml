pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Bar.right
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces
import "../../Bar/right/BarPopupRouting.js" as BarPopupRouting

QtObject {
    id: root

    readonly property bool active:
        SurfaceManager.ownerId.indexOf("bluetooth:") === 0
        && (SurfaceManager.descriptor?.barConnected !== true
            || RightPillCoordinator.connectedSurfaceActive)

    function ownerFor(screen: var): string {
        return screen?.name ? "bluetooth:" + screen.name : "";
    }

    function descriptorFor(owner: string, feature: string, invoker: var): var {
        const route = BarPopupRouting.presentation(Preferences.barStyle, feature);
        if (!route)
            return null;
        return {
            "source": Qt.resolvedUrl(route.source),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
            "feature": feature,
            "barConnected": route.owner === "edge",
            "anchor": route.anchor,
            "invoker": invoker,
        };
    }

    function open(screen: var, invoker: var): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || "");
        const owner = root.ownerFor(routedScreen);
        const descriptor = root.descriptorFor(owner, "bluetooth", invoker);
        if (!owner || !invoker || !descriptor)
            return false;
        return SurfaceManager.open(owner, descriptor, routedScreen);
    }

    function openForIpc(screen: var): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || "");
        const owner = root.ownerFor(routedScreen);
        const descriptor = root.descriptorFor(owner, "bluetooth", null);
        if (!owner || !descriptor)
            return false;
        if (SurfaceManager.ownerId === owner
                && SurfaceManager.descriptor?.barConnected === true
                && RightPillCoordinator.connectedClosing)
            return RightPillCoordinator.toggleConnectedSurface(owner);
        if (SurfaceManager.ownerId === owner)
            return true;
        return SurfaceManager.open(owner, descriptor, routedScreen);
    }

    function toggle(screen: var, invoker: var): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || "");
        const owner = root.ownerFor(routedScreen);
        if (!owner || !invoker)
            return false;
        if (SurfaceManager.ownerId === owner
                && SurfaceManager.descriptor?.barConnected === true)
            return RightPillCoordinator.toggleConnectedSurface(owner);
        if (SurfaceManager.ownerId === owner)
            return SurfaceManager.close(owner);
        return root.open(routedScreen, invoker);
    }

    function close(): bool {
        if (!root.active)
            return false;
        if (SurfaceManager.descriptor?.barConnected === true)
            return RightPillCoordinator.closeConnectedSurface();
        return SurfaceManager.close(SurfaceManager.ownerId);
    }
}
