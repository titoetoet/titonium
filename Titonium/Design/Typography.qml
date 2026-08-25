pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation

QtObject {
    id: root

    readonly property var values: ConfigStore.themeState.typography || ({})
    readonly property string fontFamily: values.fontFamily || "SF Pro Display"
    readonly property string family: root.fontFamily
    readonly property string fallbackFamily: values.fallbackFamily || "Noto Sans"
    readonly property string monoFamily: values.monoFamily || "JetBrains Mono"
    readonly property int bodySize: values.bodySize || 13
    readonly property int captionSize: values.captionSize || 11
    readonly property int labelSize: root.bodySize
    readonly property int titleSize: values.titleSize || 16
}
