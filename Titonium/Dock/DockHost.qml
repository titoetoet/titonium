pragma ComponentBehavior: Bound

import Quickshell
import qs.Titonium.Core.Screens

Scope {
    id: root

    signal applicationsRequested(var screen)

    Variants {
        model: ScreenPolicy.screens

        DockWindow {
            required property ShellScreen modelData
            screenModel: modelData
            onApplicationsRequested: screen => root.applicationsRequested(screen)
        }
    }
}
