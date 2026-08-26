pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root
    readonly property string fontFamily: "SF Pro Display"
    readonly property string family: root.fontFamily
    readonly property string fallbackFamily: "Noto Sans"
    readonly property string monoFamily: "JetBrains Mono"
    readonly property string iconFamily: "Material Symbols Rounded"
    readonly property int microSize: 10
    readonly property int bodySize: 13
    readonly property int bodySmallSize: 12
    readonly property int bodyLargeSize: 14
    readonly property int captionSize: 11
    readonly property int labelSize: 13
    readonly property int titleSmallSize: 15
    readonly property int titleSize: 16
    readonly property int titleLargeSize: 20
    readonly property int displaySize: 28
    readonly property int regularWeight: Font.Normal
    readonly property int mediumWeight: Font.Medium
    readonly property int semiboldWeight: Font.DemiBold
    readonly property int boldWeight: Font.Bold

    function sizeFor(variant: string): int {
        const sizes = { micro: 10, caption: 11, bodySmall: 12, body: 13, bodyLarge: 14,
            label: 13, titleSmall: 15, title: 16, titleLarge: 20, display: 28, mono: 13 };
        return sizes[variant] || root.bodySize;
    }

    function weightFor(variant: string): int {
        if (variant === "display" || variant === "titleLarge" || variant === "title")
            return root.semiboldWeight;
        return variant === "label" ? root.mediumWeight : root.regularWeight;
    }
}
