pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Services.Center

Scope {
    id: root
    required property ShellScreen screenModel
    required property var profile

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
