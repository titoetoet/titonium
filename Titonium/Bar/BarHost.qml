pragma ComponentBehavior: Bound

import Quickshell
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Screens

Scope {
    id: root
    signal centerRequested(var screen)
    signal sourceRequested(var screen, string intent)
    signal settingsRequested(var screen)

    Variants {
        model: ScreenPolicy.screens
        Scope {
            id: screenScope
            required property var modelData
            BarSurface {
                screenModel: screenScope.modelData
                onCenterRequested: screen => root.centerRequested(screen)
                onSourceRequested: (screen, intent) => root.sourceRequested(screen, intent)
            }
            CenterNotchWindow {
                screenModel: screenScope.modelData
                onSettingsRequested: screen => root.settingsRequested(screen)
            }
        }
    }
}
