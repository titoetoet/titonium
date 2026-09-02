pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.AgentApproval
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

    SurfaceRouter {
        id: router
    }

    Component.onCompleted: serviceBootstrap.activate()

    BarHost {
        onCenterRequested: screen => router.openCenterNotch(screen, "overview")
        onNotificationsRequested: screen => router.openCenterNotch(screen, "notifications")
        onSourceRequested: (screen, intent) => router.activateCenterSource(screen, intent)
    }

    DockHost {
        onApplicationsRequested: screen => router.openSpotlight("applications", "", "browse", screen)
    }

    OverlayHost {}
    AudioOsdHost {}
    ToastHost {}
    AgentApprovalHost {}
    SettingsHost {}

    CoreIpc { router: router }
    CenterIpc {}
    DeviceIpc {}
    AgentApprovalIpc {}
}
