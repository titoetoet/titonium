pragma ComponentBehavior: Bound

import Quickshell

Scope {
    Variants {
        model: FrameModel.enabled ? Quickshell.screens : []

        FrameSurface {
            required property var modelData
            screenModel: modelData
        }
    }
}
