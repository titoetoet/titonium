pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation

QtObject {
    id: root

    readonly property var values: ConfigStore.themeState.motion || ({})
    readonly property bool reduced: ConfigStore.previewState.accessibility?.reducedMotion || false
    readonly property int fast: reduced ? 0 : (values.fast || 120)
    readonly property int normal: reduced ? 0 : (values.normal || 180)
    readonly property int slow: reduced ? 0 : (values.slow || 260)
}

