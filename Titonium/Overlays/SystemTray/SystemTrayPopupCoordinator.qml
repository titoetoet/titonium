pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces
import qs.Titonium.Services.SystemTray

QtObject {
    id: root

    readonly property bool active:
        SurfaceManager.ownerId.indexOf("system-tray:") === 0

    function ownerFor(screen: var, target: string): string {
        return screen?.name ? "system-tray:" + screen.name + ":" + target : "";
    }

    function anchorDescriptor(invoker: var): var {
        if (!invoker)
            return { "anchorX": 0, "anchorWidth": 0 };
        const point = invoker.mapToItem(null, 0, invoker.height);
        return {
            "anchorX": Math.round(point.x),
            "anchorWidth": Math.round(invoker.width)
        };
    }

    function openPrepared(screen: var, invoker: var, target: string): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || "");
        const owner = root.ownerFor(routedScreen, target);
        if (!owner || !invoker)
            return false;
        const anchor = root.anchorDescriptor(invoker);
        return SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("SystemTrayPopupSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
            "invoker": invoker,
            "anchorX": anchor.anchorX,
            "anchorWidth": anchor.anchorWidth
        }, routedScreen);
    }

    function toggleApp(screen: var, invoker: var,
            appId: string, appName: string): bool {
        const owner = root.ownerFor(ScreenRouter.screenForName(screen?.name || ""), "app");
        if (owner && SurfaceManager.ownerId === owner)
            return root.close();
        if (!SystemTrayService.prepareAppMenu(appId, appName))
            return false;
        return root.openPrepared(screen, invoker, "app");
    }

    function toggleInput(screen: var, invoker: var): bool {
        const owner = root.ownerFor(ScreenRouter.screenForName(screen?.name || ""), "input");
        if (owner && SurfaceManager.ownerId === owner)
            return root.close();
        if (!SystemTrayService.prepareInputMenu())
            return false;
        return root.openPrepared(screen, invoker, "input");
    }

    function close(): bool {
        if (!root.active)
            return false;
        SystemTrayService.resetPopupNavigation();
        return SurfaceManager.close(SurfaceManager.ownerId);
    }
}
