pragma ComponentBehavior: Bound

import Quickshell
import qs.Titonium.Bar.right
import qs.Titonium.Core.Screens
import qs.Titonium.Core.Surfaces.Center
import "center/CenterPresentationRules.js" as CenterPresentationRules

Scope {
    id: root
    signal settingsRequested(var screen)

    Variants {
        model: ScreenPolicy.screens
        Scope {
            id: screenScope
            required property var modelData
            BarSurface {
                screenModel: screenScope.modelData
            }
            CenterSurfaceHost {
                screenModel: screenScope.modelData
                profile: CenterPresentationRules.profile(RightPillCoordinator.presentedStyle)
            }
            EdgeMenuWindow {
                screenModel: screenScope.modelData
                styleActive: RightPillCoordinator.presentedStyle === "connected"
            }
        }
    }
}
