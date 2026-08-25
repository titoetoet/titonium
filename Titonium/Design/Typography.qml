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
    readonly property string iconFamily: values.iconFamily || "Material Symbols Rounded"
    readonly property int microSize: values.microSize || Math.max(9, root.bodySize - 3)
    readonly property int bodySize: values.bodySize || 13
    readonly property int bodySmallSize: values.bodySmallSize || Math.max(10, root.bodySize - 1)
    readonly property int bodyLargeSize: values.bodyLargeSize || root.bodySize + 1
    readonly property int captionSize: values.captionSize || 11
    readonly property int labelSize: values.labelSize || root.bodySize
    readonly property int titleSmallSize: values.titleSmallSize || Math.max(13, root.titleSize - 1)
    readonly property int titleSize: values.titleSize || 16
    readonly property int titleLargeSize: values.titleLargeSize || root.titleSize + 4
    readonly property int displaySize: values.displaySize || root.titleSize * 2
    readonly property var weights: values.weights || ({})
    readonly property int regularWeight: weights.regular || Font.Normal
    readonly property int mediumWeight: weights.medium || Font.Medium
    readonly property int semiboldWeight: weights.semibold || Font.DemiBold
    readonly property int boldWeight: weights.bold || Font.Bold

    function sizeFor(variant: string): int {
        const sizes = {
            micro: root.microSize,
            caption: root.captionSize,
            bodySmall: root.bodySmallSize,
            body: root.bodySize,
            bodyLarge: root.bodyLargeSize,
            label: root.labelSize,
            titleSmall: root.titleSmallSize,
            title: root.titleSize,
            titleLarge: root.titleLargeSize,
            display: root.displaySize,
            mono: root.bodySize
        };
        return sizes[variant] || root.bodySize;
    }

    function weightFor(variant: string): int {
        if (variant === "display" || variant === "titleLarge" || variant === "title")
            return root.semiboldWeight;
        if (variant === "label")
            return root.mediumWeight;
        return root.regularWeight;
    }
}
