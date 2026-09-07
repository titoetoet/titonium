pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Theme

// Keep one glyph layout throughout the morph; only transform its texture geometry.
Item {
    id: root
    property string text: ""
    property real progress: 0
    property bool playing: false
    property bool animationEnabled: true
    readonly property bool animated: visible && opacity > 0 && playing && animationEnabled
        && !Motion.reduced && (progress === 0 || progress === 1)
    readonly property real maximumScroll: Math.max(0, glyphs.implicitWidth * textScale - width)
    readonly property bool scrolling: animated && maximumScroll > 0
    readonly property bool shimmerActive: animated
    property real scrollOffset: 0
    property real sweep: -24
    implicitHeight: 24
    onTextChanged: { scrollOffset = 0; if (scrolling) marquee.restart(); }
    onScrollingChanged: { if (!scrolling) scrollOffset = 0; }
    onAnimatedChanged: { if (!animated) sweep = -24; }
    property color surfaceColor: Theme.centerSurface
    readonly property real textScale: Typography.bodySize / Typography.titleSize
        + (1 - Typography.bodySize / Typography.titleSize) * root.progress
    readonly property int glyphPixelSize: Typography.titleSize
    readonly property int glyphWeight: Typography.semiboldWeight
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
    Text {
        id: glyphs
        objectName: "musicTitleGlyphs"
        x: -root.scrollOffset
        opacity: root.shimmerActive ? 0.78 : 1
        text: root.text
        textFormat: Text.PlainText
        font.family: Typography.family
        font.pixelSize: root.glyphPixelSize
        font.weight: root.glyphWeight
        color: Theme.textPrimary
        renderType: Text.QtRendering
        transformOrigin: Item.TopLeft
        scale: root.textScale
        y: (root.height - implicitHeight * scale) / 2
    }
    // Five narrow alpha bands soften the highlight without Canvas repaints or blur.
    Item {
        visible: root.shimmerActive
        x: root.sweep
        width: 20; height: root.height
        Repeater {
            model: 5
            Item {
                required property int index
                x: index * 4; width: 4; height: root.height
                clip: true
                opacity: [0.15, 0.4, 0.75, 0.4, 0.15][index]
                Text {
                    x: -root.sweep - parent.x - root.scrollOffset
                    y: glyphs.y
                    text: root.text
                    textFormat: Text.PlainText
                    font: glyphs.font
                    color: Theme.textPrimary
                    renderType: Text.QtRendering
                    transformOrigin: Item.TopLeft
                    scale: root.textScale
                }
            }
        }
    }
    SequentialAnimation {
        id: marquee
        running: root.scrolling
        loops: Animation.Infinite
        PauseAnimation { duration: 1100 }
        NumberAnimation {
            target: root; property: "scrollOffset"; from: 0; to: root.maximumScroll
            duration: Math.max(1800, root.maximumScroll / 28 * 1000)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 1200 }
        NumberAnimation { target: root; property: "scrollOffset"; to: 0; duration: 350 }
    }
    SequentialAnimation {
        running: root.shimmerActive
        loops: Animation.Infinite
        NumberAnimation { target: root; property: "sweep"; from: -24; to: root.width + 24; duration: 1800 }
        PauseAnimation { duration: 3200 }
    }
    Rectangle {
        anchors.right: parent.right
        width: Math.min(18, parent.width); height: parent.height
        visible: glyphs.implicitWidth * root.textScale > root.width
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: root.surfaceColor }
        }
    }
}
