pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Shared.styles
import "StyleRules.js" as StyleRules

// Content and input handlers always remain outside this replaceable paint tree.
Item {
    id: root
    required property var tokens
    property string role: "surface"
    property var interaction: ({})
    property real radius: tokens.design?.controlRadius ?? 4
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    property color customColor: "transparent"
    property color borderColor: tokens.colors?.border || "#4a5360"
    property bool outlined: true
    property bool showFocus: true
    property var backdropCapability: ({level: "none", available: false})
    function boundedRadius(value: real): real {
        return value < 0 ? Math.min(width,height) / 2 : Math.max(0,Math.min(value,width / 2,height / 2));
    }
    readonly property var geometry: ({radius:boundedRadius(radius), topLeftRadius:boundedRadius(topLeftRadius),
        topRightRadius:boundedRadius(topRightRadius), bottomLeftRadius:boundedRadius(bottomLeftRadius), bottomRightRadius:boundedRadius(bottomRightRadius)})
    readonly property var paint: {
        const result = StyleRules.paint(tokens, role, interaction);
        if (customColor.a > 0) result.fill = customColor;
        result.outline = borderColor;
        if (!outlined) result.borderStrength = 0;
        return result;
    }
    readonly property var motion: StyleRules.controlMotion(tokens)
    readonly property string renderer: tokens.design?.renderer || "modern-flat"
    readonly property alias paintItem: loader.item

    Loader {
        id: loader
        anchors.fill: parent
        active: root.visible
        sourceComponent: root.renderer === "material" ? material
            : root.renderer === "neumorphism" ? neumorphic
            : root.renderer === "glassmorphism" ? frosted
            : root.renderer === "liquid-glass" ? liquid : flat
    }
    Component { id: flat; FlatPaint { paint: root.paint; geometry: root.geometry; motion: root.motion } }
    Component { id: material; MaterialPaint { paint: root.paint; geometry: root.geometry; motion: root.motion } }
    Component { id: frosted; FrostedPaint { paint: root.paint; geometry: root.geometry; motion: root.motion } }
    Component { id: liquid; LiquidPaint { paint: root.paint; geometry: root.geometry; motion: root.motion } }
    Component { id: neumorphic; NeumorphicPaint { paint: root.paint; geometry: root.geometry; motion: root.motion } }

    Rectangle {
        objectName: "styleSelection"
        visible: root.paint.indicator
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 3
        width: Math.min(16, parent.width * .4)
        height: 2
        radius: 1
        color: root.paint.accent
    }
    StyleFocusRing {
        anchors.fill: parent
        anchors.margins: 1
        focused: root.showFocus && root.paint.focused
        focusColor: root.paint.focus
        radius: root.radius
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
    }
}
