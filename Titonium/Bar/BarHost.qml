pragma ComponentBehavior: Bound

import Quickshell
import qs.Titonium.Bar.notch
import qs.Titonium.Bar.right
import qs.Titonium.Core.Screens

Scope {
    id: root
    signal centerRequested(var screen)
    signal bannerRequested(var screen, var context, bool autoDismiss)
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
            CenterPillWindow {
                screenModel: screenScope.modelData
                styleActive: RightPillCoordinator.presentedStyle === "connected"
                onBannerRequested: (screen, context, autoDismiss) =>
                    root.bannerRequested(screen, context, autoDismiss)
                onSettingsRequested: screen => root.settingsRequested(screen)
            }
            EdgeMenuWindow {
                screenModel: screenScope.modelData
                styleActive: RightPillCoordinator.presentedStyle === "connected"
            }
        }
    }
}
