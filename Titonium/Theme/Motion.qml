pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime

QtObject {
    readonly property bool reduced: Preferences.reducedMotion
    readonly property int fast: reduced ? 0 : 100
    readonly property int normal: reduced ? 0 : 160
    readonly property int slow: reduced ? 0 : 220
}
