pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Titonium.Foundation

QtObject {
    id: root

    readonly property var values: ConfigStore.themeState.metrics || ({})
    readonly property int barHeight: ConfigStore.layoutState.menubar?.height || values.barHeight || 40
    readonly property int barPadding: values.barPadding || 8
    readonly property int widgetHeight: values.widgetHeight || 28
    readonly property int spacing: values.spacing || 6
    readonly property int spacingXSmall: Math.max(2, Math.round(root.spacing * 0.67))
    readonly property int spacingSmall: root.spacing
    readonly property int spacingMedium: Math.round(root.spacing * 2)
    readonly property int controlHeightSmall: root.widgetHeight
    readonly property int radiusSmall: values.radiusSmall || 7
    readonly property int radiusMedium: values.radiusMedium || 12
    readonly property int radiusLarge: values.radiusLarge || 20
}
