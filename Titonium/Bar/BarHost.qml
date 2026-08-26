pragma ComponentBehavior: Bound

import Quickshell
import qs.Titonium.Bar.notch

Scope {
    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property var modelData
            BarSurface { screenModel: screenScope.modelData }
            CenterNotchWindow { screenModel: screenScope.modelData }
        }
    }
}
