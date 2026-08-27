pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces

QtObject {
    id: root

    readonly property bool active: SurfaceManager.ownerId.indexOf("network:") === 0

    function ownerFor(screen: var): string {
        return screen?.name ? "network:" + screen.name : "";
    }

    function open(screen: var, invoker: var): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || "");
        const owner = root.ownerFor(routedScreen);
        if (!owner)
            return false;
        return SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("NetworkPopupSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
            "invoker": invoker,
        }, routedScreen);
    }

    function openForIpc(screen: var): bool {
        return root.open(screen, null);
    }

    function toggle(screen: var, invoker: var): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || "");
        const owner = root.ownerFor(routedScreen);
        if (!owner || !invoker)
            return false;
        if (SurfaceManager.ownerId === owner)
            return SurfaceManager.close(owner);
        return root.open(routedScreen, invoker);
    }

    function close(): bool {
        if (!root.active)
            return false;
        return SurfaceManager.close(SurfaceManager.ownerId);
    }
}
