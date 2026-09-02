pragma ComponentBehavior: Bound

import Quickshell
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Screens

Scope {
    id: root
    signal centerRequested(var screen)
    signal notificationsRequested(var screen)
    signal sourceRequested(var screen, string intent)

    Variants {
        model: ScreenPolicy.screens
        Scope {
            id: screenScope
            required property var modelData
            BarSurface {
                screenModel: screenScope.modelData
                onCenterRequested: screen => root.centerRequested(screen)
                onNotificationsRequested: screen => root.notificationsRequested(screen)
                onSourceRequested: (screen, intent) => root.sourceRequested(screen, intent)
            }
            CenterNotchWindow {
                screenModel: screenScope.modelData
            }
        }
    }
}
