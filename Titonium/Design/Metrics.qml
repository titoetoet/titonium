pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation

QtObject {
    id: root

    readonly property var values: ConfigStore.themeState.metrics || ({})
    readonly property int barHeight: ConfigStore.layoutState.menubar?.height || values.barHeight || 40
    readonly property int grid: values.grid || 4
    readonly property int barPadding: values.barPadding || 8
    readonly property int controlHeightSmall: values.controlHeightSmall || 28
    readonly property int controlHeight: values.controlHeight || 32
    readonly property int widgetHeight: root.controlHeightSmall
    readonly property int spacingXSmall: values.spacingXSmall || root.grid
    readonly property int spacingSmall: values.spacingSmall || root.grid * 2
    readonly property int spacingMedium: values.spacingMedium || root.grid * 3
    readonly property int spacingLarge: values.spacingLarge || root.grid * 4
    readonly property int spacing: root.spacingSmall
    readonly property int radiusSmall: values.radiusSmall || 4
    readonly property int radiusMedium: values.radiusMedium || 8
    readonly property int radiusLarge: values.radiusLarge || 12
    readonly property int borderWidth: values.borderWidth || 1
}
