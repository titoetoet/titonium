pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center

Scope {
    id: root
    required property ShellScreen screenModel
    required property var profile
    readonly property bool pointerHovered: compactWindow.pointerHovered || overlayWindow.pointerHovered
    onPointerHoveredChanged: BarVisibilityState.setCenterHovered(root.screenModel.name, root.pointerHovered)

    Component.onCompleted: {
        if (CenterSurfaceController.mode === "closed")
            CenterSurfaceController.dispatch({ type: "surface-granted",
                screenName: root.screenModel.name });
    }

    Component.onDestruction: {
        BarVisibilityState.setCenterHovered(root.screenModel.name, false);
        if (CenterSurfaceController.ownerScreenName === root.screenModel.name)
            CenterSurfaceController.dispatch({
                type: "surface-revoked",
                reason: "screen-removed",
            });
    }

    CenterCompactWindow {
        id: compactWindow
        screenModel: root.screenModel
        snapshot: CenterDomain.presentationSnapshot
        viewState: CenterSurfaceController.viewState
        profile: root.profile
    }
    CenterOverlayWindow {
        id: overlayWindow
        screenModel: root.screenModel
        snapshot: CenterDomain.presentationSnapshot
        viewState: CenterSurfaceController.viewState
        profile: root.profile
    }
}
