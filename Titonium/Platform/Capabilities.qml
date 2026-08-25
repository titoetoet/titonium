pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Platform.Hyprland

QtObject {
    readonly property bool hyprglassLoaded: HyprglassCapability.loaded
    readonly property bool hyprglassProbed: HyprglassCapability.probed
    readonly property string hyprglassDetail: HyprglassCapability.detail
    readonly property bool nativeGlassAvailable: hyprglassLoaded
}
