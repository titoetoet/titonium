pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Theme
import "IconRules.js" as IconRules

Item {
    id: root
    required property string name
    property int size: 20
    property string tone: root.enabled ? "primary" : "disabled"
    property real fill: 0
    property string accessibleName: ""
    property color color: root.resolvedColor
    readonly property string resolvedName: IconRules.semanticName(root.name, "image")
    readonly property color resolvedColor: ({ primary: Theme.textPrimary,
        secondary: Theme.textSecondary, disabled: Theme.textDisabled, accent: Theme.accentForeground,
        success: Theme.success, warning: Theme.warning, danger: Theme.danger })[root.tone]
        || Theme.textPrimary

    implicitWidth: root.size
    implicitHeight: root.size

    Text {
        anchors.fill: parent
        visible: Typography.iconFontReady
        text: root.resolvedName
        color: root.color
        font.family: Typography.iconFamily
        font.pixelSize: root.size
        font.weight: Font.Medium
        font.variableAxes: ({ "FILL": root.fill, "GRAD": -25, "opsz": root.size, "wght": 500 })
        renderType: Text.QtRendering
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Accessible.ignored: root.accessibleName.length === 0
    Accessible.name: root.accessibleName
}
