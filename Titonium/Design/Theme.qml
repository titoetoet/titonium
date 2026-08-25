pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation

QtObject {
    id: root

    readonly property string id: ConfigStore.themeState.id || "titonium-neutral"
    readonly property string mode: ConfigStore.previewState.appearance?.mode || "dark"
    readonly property var modeDocument: ConfigStore.themeState.modes?.[root.mode] || ({ colors: {} })
    readonly property var colors: root.modeDocument.colors || ({})

    readonly property color background: colors.background || "#111318"
    readonly property color surface: colors.surface || "#20242c"
    readonly property color surfaceElevated: colors.surfaceElevated || "#292e38"
    readonly property color surfaceInteractive: colors.surfaceInteractive || "#292e38"
    readonly property color textPrimary: colors.textPrimary || "#f5f7fa"
    readonly property color textSecondary: colors.textSecondary || "#aeb7c4"
    readonly property color textDisabled: colors.textDisabled || "#707985"
    readonly property color border: colors.border || "#3a4250"
    readonly property color borderStrong: colors.borderStrong || "#4a5360"
    readonly property color accent: colors.accent || "#78a9ff"
    readonly property color accentText: colors.accentText || "#07111f"
    readonly property color focus: colors.focus || "#8bb8ff"
    readonly property color success: colors.success || "#66d9a8"
    readonly property color warning: colors.warning || "#ffca6a"
    readonly property color danger: colors.danger || "#ff7b86"
}
