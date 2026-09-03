pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime

QtObject {
    readonly property bool reduced: Preferences.reducedMotion
    readonly property int fast: reduced ? 0 : 100
    readonly property int normal: reduced ? 0 : 160
    readonly property int slow: reduced ? 0 : 220

    // Critically Damped Spring: Rapid initial acceleration, zero-overshoot magnetic settle.
    // Equivalent to Apple iOS/macOS fluid spring & Linear UI: cubic-bezier(0.16, 1, 0.3, 1)
    readonly property var springDamped: [0.16, 1, 0.3, 1, 1, 1]

    // Snappy Micro-Spring: Quick response for interactive controls: cubic-bezier(0.2, 1, 0.25, 1)
    readonly property var springSnappy: [0.2, 1, 0.25, 1, 1, 1]
}
