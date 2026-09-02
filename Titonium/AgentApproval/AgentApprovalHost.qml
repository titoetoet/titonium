pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Scope {
    Variants {
        // Approval is the only Titonium surface allowed to follow focus across
        // monitors. All regular shell surfaces still obey ScreenPolicy.
        model: Quickshell.screens
        AgentApprovalWindow {
            required property ShellScreen modelData
            screenModel: modelData
        }
    }
}
