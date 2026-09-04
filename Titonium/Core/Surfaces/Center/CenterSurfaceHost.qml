pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Services.Center

Scope {
    id: root
    required property ShellScreen screenModel
    required property var profile

    Component.onCompleted: {
        if (CenterSurfaceController.mode === "closed")
            CenterSurfaceController.dispatch({ type: "surface-granted",
                screenName: root.screenModel.name });
    }

    Component.onDestruction: {
        if (CenterSurfaceController.ownerScreenName === root.screenModel.name)
            CenterSurfaceController.dispatch({
                type: "surface-revoked",
                reason: "screen-removed",
            });
    }

    CenterCompactWindow {
        screenModel: root.screenModel
        snapshot: CenterDomain.snapshot
        viewState: CenterSurfaceController.viewState
        profile: root.profile
    }
    CenterOverlayWindow {
        screenModel: root.screenModel
        snapshot: CenterDomain.snapshot
        viewState: CenterSurfaceController.viewState
        profile: root.profile
    }
}
