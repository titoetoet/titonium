pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Titonium.Bar
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Surfaces
import qs.Titonium.Dock
import qs.Titonium.Ipc
import qs.Titonium.Notifications
import qs.Titonium.Orchestration
import qs.Titonium.Osd.Audio
import qs.Titonium.Settings
import qs.Titonium.Theme

Scope {
    id: root
    Binding { target: Metrics; property: "barHeight"; value: Preferences.bar.height || 44 }

    ServiceBootstrap { id: serviceBootstrap }
    BluetoothAudioBridge {}
    NotificationBridge {}

    SurfaceRouter {
        id: router
    }

    Component.onCompleted: serviceBootstrap.activate()

    BarHost {
        onSettingsRequested: screen => router.openSettings(screen, "bar")
        onNotificationsRequested: (screen, invoker) =>
            router.toggleNotificationPanel(screen, invoker)
    }

    GlobalShortcut {
        appid: "titonium"
        name: "dynamicIsland"
        description: "Open Expanded Dynamic Island"
        onPressed: router.openCenter(null, "overview", "")
    }

    GlobalShortcut {
        appid: "titonium"
        name: "notifications"
        description: I18n.tr("shortcut.notifications.description")
        onPressed: router.toggleNotificationPanel(null, null)
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
