pragma ComponentBehavior: Bound

import Quickshell

Scope {
    Variants {
        model: Quickshell.screens
        BarSurface {
            required property var modelData
            screenModel: modelData
        }
    }
}
