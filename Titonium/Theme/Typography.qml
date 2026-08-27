pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import "TypographyScale.js" as TypographyScale

QtObject {
    id: root
    readonly property string fontFamily: "SF Pro Display"
    readonly property string family: root.fontFamily
    readonly property string fallbackFamily: "Noto Sans"
    readonly property string monoFamily: "JetBrains Mono"
    readonly property string iconFamily: "Material Symbols Rounded"
    readonly property int microSize: TypographyScale.sizeFor("micro")
    readonly property int bodySize: TypographyScale.sizeFor("body")
    readonly property int bodySmallSize: TypographyScale.sizeFor("bodySmall")
    readonly property int bodyLargeSize: TypographyScale.sizeFor("bodyLarge")
    readonly property int captionSize: TypographyScale.sizeFor("caption")
    readonly property int labelSize: TypographyScale.sizeFor("label")
    readonly property int titleSmallSize: TypographyScale.sizeFor("titleSmall")
    readonly property int titleSize: TypographyScale.sizeFor("title")
    readonly property int titleLargeSize: TypographyScale.sizeFor("titleLarge")
    readonly property int displaySize: TypographyScale.sizeFor("display")
    readonly property int regularWeight: Font.Normal
    readonly property int mediumWeight: Font.Medium
    readonly property int semiboldWeight: Font.DemiBold
    readonly property int boldWeight: Font.Bold

    function sizeFor(variant: string): int {
        return TypographyScale.sizeFor(variant);
    }

    function weightFor(variant: string): int {
        if (variant === "display" || variant === "titleLarge" || variant === "title")
            return root.semiboldWeight;
        return variant === "label" ? root.mediumWeight : root.regularWeight;
    }
}
