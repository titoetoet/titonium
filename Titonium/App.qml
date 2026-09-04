pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Titonium.Bar
import qs.Titonium.Core.Surfaces
import qs.Titonium.Dock
import qs.Titonium.Ipc
import qs.Titonium.Notifications
import qs.Titonium.Orchestration
import qs.Titonium.Osd.Audio
import qs.Titonium.Settings

Scope {
    id: root

    ServiceBootstrap { id: serviceBootstrap }
    BluetoothAudioBridge {}
    NotificationBridge {}

    SurfaceRouter {
        id: router
    }

    Component.onCompleted: serviceBootstrap.activate()

    BarHost {
        onSettingsRequested: screen => router.openSettings(screen, "bar")
    }

    GlobalShortcut {
        appid: "titonium"
        name: "dynamicIsland"
        description: "Open Expanded Dynamic Island"
        onPressed: router.openCenter(null, "overview", "")
    }

    DockHost {
        onApplicationsRequested: screen => router.openSpotlight("applications", "", "browse", screen)
    }

    OverlayHost {}
    AudioOsdHost {}
    ToastHost {}
    SettingsHost {}

    CoreIpc { router: router }
    CenterIpc {}
    DeviceIpc {}
    AgentApprovalIpc {}
}
