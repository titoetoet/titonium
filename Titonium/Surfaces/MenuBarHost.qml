pragma ComponentBehavior: Bound

import Quickshell

Scope {
    Variants {
        model: Quickshell.screens

        MenuBarSurface {
            required property var modelData
            screenModel: modelData
        }
    }
}
