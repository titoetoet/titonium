pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    readonly property int grid: 4
    readonly property int barHeight: 40
    readonly property int barPadding: 8
    readonly property int barSpacing: 8
    readonly property int controlHeightSmall: 28
    readonly property int controlHeight: 32
    readonly property int widgetHeight: 28
    readonly property int spacingXSmall: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16
    readonly property int spacing: 8
    readonly property int radiusSmall: 4
    readonly property int radiusMedium: 8
    readonly property int radiusLarge: 12
    readonly property int borderWidth: 1
}
