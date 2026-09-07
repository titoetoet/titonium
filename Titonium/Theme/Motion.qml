pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Services.Appearance

QtObject {
    readonly property bool reduced: AppearanceService.tokens.reducedMotion
    readonly property real layoutScale: AppearanceService.tokens.legacy === false ? 1 : AppearanceService.tokens.motionScale
    readonly property int controlDuration: reduced ? 0 : Math.round((AppearanceService.tokens.design?.controlMotion?.durationMs || 100) * AppearanceService.tokens.motionScale)
    readonly property string controlCurve: AppearanceService.tokens.design?.controlMotion?.curve || "standard"
    readonly property real controlPressScale: reduced ? 1 : AppearanceService.tokens.design?.controlMotion?.pressScale ?? 1
    readonly property int fast: reduced ? 0 : Math.round(100 * layoutScale)
    readonly property int normal: reduced ? 0 : Math.round(160 * layoutScale)
    readonly property int slow: reduced ? 0 : Math.round(220 * layoutScale)

    // Critically Damped Spring: Rapid initial acceleration, zero-overshoot magnetic settle.
    // Equivalent to Apple iOS/macOS fluid spring & Linear UI: cubic-bezier(0.16, 1, 0.3, 1)
    readonly property var springDamped: [0.16, 1, 0.3, 1, 1, 1]

    // Snappy Micro-Spring: Quick response for interactive controls: cubic-bezier(0.2, 1, 0.25, 1)
    readonly property var springSnappy: [0.2, 1, 0.25, 1, 1, 1]
}
