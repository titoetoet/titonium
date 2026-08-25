pragma Singleton

import QtQuick
import qs.Titonium.Foundation

QtObject {
    readonly property var state: ConfigStore.previewState.modules?.frame || ({})
    readonly property bool enabled: state.enabled === true
    readonly property int thickness: Math.max(1, Math.min(8, state.thickness || 2))
    readonly property int cornerRadius: Math.max(0, Math.min(32, state.cornerRadius || 0))
    readonly property real opacity: Math.max(0.3, Math.min(1.0, state.opacity ?? 0.85))
}
