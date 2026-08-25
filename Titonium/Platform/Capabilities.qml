pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    // Milestone 0 deliberately has no command probe. A future Hyprland adapter
    // updates this property from an event/one-shot capability check.
    property bool hyprglassLoaded: false
    readonly property bool nativeGlassAvailable: hyprglassLoaded
}

