pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Core.Screens

Scope {
    Variants {
        model: ScreenPolicy.screens

        SettingsWindow {
            required property ShellScreen modelData
            screenModel: modelData
        }
    }
}
