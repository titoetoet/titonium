pragma ComponentBehavior: Bound

import Quickshell
import qs.Titonium.Bar.notch
import qs.Titonium.Core.Screens

Scope {
    Variants {
        model: ScreenPolicy.screens
        Scope {
            id: screenScope
            required property var modelData
            BarSurface { screenModel: screenScope.modelData }
            CenterNotchWindow { screenModel: screenScope.modelData }
        }
    }
}
