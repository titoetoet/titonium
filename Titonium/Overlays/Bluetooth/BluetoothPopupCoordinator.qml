pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces

QtObject {
    id: root

    readonly property bool active: SurfaceManager.ownerId.indexOf("bluetooth:") === 0

    function ownerFor(screen: var): string {
        return screen?.name ? "bluetooth:" + screen.name : "";
    }

    function open(screen: var): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || "");
        const owner = root.ownerFor(routedScreen);
        if (!owner)
            return false;
        return SurfaceManager.open(owner, {
            "source": Qt.resolvedUrl("BluetoothPopupSurface.qml"),
            "keyboardFocus": "exclusive",
            "closeOnMonitorChange": true,
            "ownerId": owner,
        }, routedScreen);
    }

    function toggle(screen: var): bool {
        const routedScreen = ScreenRouter.screenForName(screen?.name || "");
        const owner = root.ownerFor(routedScreen);
        if (!owner)
            return false;
        if (SurfaceManager.ownerId === owner)
            return SurfaceManager.close(owner);
        return root.open(routedScreen);
    }

    function close(): bool {
        if (!root.active)
            return false;
        return SurfaceManager.close(SurfaceManager.ownerId);
    }
}
