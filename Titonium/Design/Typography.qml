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
    readonly property int labelSize: values.labelSize || root.bodySize
    readonly property int titleSize: values.titleSize || 16
    readonly property var weights: values.weights || ({})
    readonly property int regularWeight: weights.regular || Font.Normal
    readonly property int mediumWeight: weights.medium || Font.Medium
    readonly property int semiboldWeight: weights.semibold || Font.DemiBold
    readonly property int boldWeight: weights.bold || Font.Bold
}
