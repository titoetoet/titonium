pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Theme

Item {
    id: root
    property string text: ""
    property bool playing: false
    property bool engaged: false
    readonly property real maximumWidth: 200
    property font font: Qt.font({family: Typography.family, pixelSize: Typography.sizeFor("body"), weight: Typography.weightFor("body")})
    readonly property real contentWidth: metrics.advanceWidth
    readonly property bool overflowing: root.contentWidth > root.width
    readonly property real maximumScroll: Math.max(0, root.contentWidth - root.width)
    readonly property bool scrolling: root.visible && (root.engaged || root.playing) && root.overflowing && !Motion.reduced
    readonly property bool shimmerActive: root.visible && root.playing && !root.scrolling && !Motion.reduced
    property real scrollOffset: 0
    property real sweep: -0.3
    implicitWidth: Math.min(root.maximumWidth, root.contentWidth)
    implicitHeight: Math.ceil(metrics.height) + 4
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: root.text
    TextMetrics { id: metrics; text: root.text; font: root.font }
    onTextChanged: { marquee.stop(); root.scrollOffset = 0; if (root.scrolling) marquee.start(); ink.requestPaint(); }
    onScrollingChanged: { if (!root.scrolling) { marquee.stop(); root.scrollOffset = 0; } }
    onScrollOffsetChanged: ink.requestPaint()
    onSweepChanged: ink.requestPaint()
    onShimmerActiveChanged: ink.requestPaint()
    onFontChanged: ink.requestPaint()
    Canvas {
        id: ink
        anchors.fill: parent
        // Canvas coordinates are logical pixels; Qt handles the screen scale.
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, canvasSize.width, canvasSize.height);
            ctx.font = String(root.font.weight) + " " + root.font.pixelSize + "px \"" + root.font.family + "\"";
            ctx.textBaseline = "middle";
            ctx.fillStyle = Theme.textPrimary.toString();
            ctx.globalAlpha = root.shimmerActive ? 0.5 : 1;
            ctx.fillText(root.text, -root.scrollOffset, height / 2);
            ctx.globalAlpha = 1;
            if (root.shimmerActive) {
                const x = root.sweep * width;
                const light = ctx.createLinearGradient(x - 10, 0, x + 10, height);
                light.addColorStop(0, "transparent");
                light.addColorStop(0.5, Theme.textPrimary.toString());
                light.addColorStop(1, "transparent");
                ctx.fillStyle = light;
                // Drawing through the glyphs is the alpha mask; the text never translates.
                ctx.fillText(root.text, 0, height / 2);
            }
            if (root.overflowing) {
                const fade = ctx.createLinearGradient(Math.max(0, width - 22), 0, width, 0);
                fade.addColorStop(0, "white");
                fade.addColorStop(1, root.scrollOffset >= root.maximumScroll - 0.5 ? "white" : "transparent");
                ctx.globalCompositeOperation = "destination-in";
                ctx.fillStyle = fade;
                ctx.fillRect(0, 0, width, height);
            }
        }
    }
    SequentialAnimation {
        id: marquee
        running: root.scrolling
        loops: Animation.Infinite
        PauseAnimation { duration: 500 }
        NumberAnimation { target: root; property: "scrollOffset"; to: root.maximumScroll; duration: Math.max(1800, root.maximumScroll / 28 * 1000); easing.type: Easing.Linear }
        PauseAnimation { duration: 800 }
        NumberAnimation { target: root; property: "scrollOffset"; to: 0; duration: 300; easing.type: Easing.OutCubic }
    }
    NumberAnimation on sweep {
        from: -0.3; to: 1.3; duration: 1800
        loops: Animation.Infinite
        running: root.shimmerActive
    }
    Connections {
        target: Theme
        function onLightChanged(): void { ink.requestPaint(); }
    }
}
