pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime

QtObject {
    id: root

    readonly property bool light: Preferences.settings.appearance?.mode === "light"
    readonly property color background: light ? "#f3f5f7" : "#111318"
    readonly property color surface: light ? "#ffffff" : "#181b20"
    readonly property color surfaceElevated: light ? "#f8f9fb" : "#20242b"
    readonly property color surfaceInteractive: light ? "#eceff3" : "#292e37"
    readonly property color textPrimary: light ? "#1b1f24" : "#f2f4f7"
    readonly property color textSecondary: light ? "#5e6773" : "#a9b0ba"
    readonly property color textDisabled: light ? "#929aa5" : "#707985"
    readonly property color border: light ? "#d7dce2" : "#343a44"
    readonly property color borderStrong: light ? "#b7bec8" : "#4a5360"
    readonly property color accent: light ? "#1769e0" : "#5b9cff"
    readonly property color accentText: light ? "#ffffff" : "#07111f"
    readonly property color focus: light ? "#0f5fcf" : "#8bb8ff"
    readonly property color success: light ? "#16825d" : "#3ccb8e"
    readonly property color warning: light ? "#a76000" : "#e8b44f"
    readonly property color danger: light ? "#c43145" : "#f06a75"
    readonly property var workspacePalette: light
        ? ["#dbeafe", "#dcfce7", "#fef3c7", "#f3e8ff", "#ffe4e6"]
        : ["#233a5e", "#1f4a3b", "#58451d", "#49305f", "#5a2934"]
    readonly property var workspaceActivePalette: light
        ? ["#93c5fd", "#86efac", "#fcd34d", "#d8b4fe", "#fda4af"]
        : ["#5b8fce", "#479a72", "#aa7d2d", "#8a5fb0", "#ad5265"]
}
