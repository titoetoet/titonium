pragma ComponentBehavior: Bound
import QtQuick
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root
    property var context: null
    property var audioLevels: [0, 0, 0, 0]
    property bool satellite: false
    property double now: Date.now()
    readonly property bool privacy: root.context?.source === "capture" && root.context?.kind !== "screenshot"
    readonly property bool media: root.context?.source === "media"
    readonly property bool focusRing: root.satellite && root.context?.source === "focus"
    readonly property real remaining: Math.max(0, Math.min(1,
        (Number(root.context?.details?.deadline || 0) - root.now)
        / Math.max(1, Number(root.context?.details?.durationMs || 1))))
    readonly property bool animate: root.visible && !Motion.reduced
    property real pulse: 1
    Shared.SystemIcon {
        anchors.centerIn: parent
        visible: !root.privacy && !root.media
        size: root.focusRing ? 12 : Math.min(20, root.height)
        sourceName: root.context?.icon || ""
        fallbackName: root.context?.icon || "center_focus_strong"
    }
    Row {
        height: 14
        anchors.centerIn: parent
        spacing: 2
        visible: root.media
        Repeater {
            model: root.satellite ? 3 : 4
            Rectangle {
                required property int index
                objectName: "audioBar" + index
                width: 3
                readonly property real sample: root.animate && root.context?.details?.playing === true
                    ? Math.max(0, Math.min(1, Number(root.satellite ? (index === 0 ? root.audioLevels[0] : index === 1
                        ? Math.max(root.audioLevels[1], root.audioLevels[2]) : root.audioLevels[3]) : root.audioLevels[index]) || 0)) : 0
                // Damped amplitude changes; a stable center and no overshoot.
                property real envelope: sample
                height: 3 + 11 * (root.animate ? Math.max(0, Math.min(1, envelope)) : 0)
                y: (14 - height) / 2
                radius: width / 2
                color: Theme.light ? "#686470" : "#e0e0e0"
                Behavior on envelope {
                    enabled: !Motion.reduced
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        visible: root.privacy
        width: 16; height: width; radius: width / 2
        color: Theme.danger
        opacity: root.pulse * 0.2
        scale: 1 + (1 - root.pulse) * 0.3
    }
    Rectangle {
        anchors.centerIn: parent
        visible: root.privacy
        width: 8; height: width; radius: width / 2
        color: Theme.danger
        opacity: root.pulse
    }
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.visible && root.focusRing
        onTriggered: root.now = Date.now()
    }
    Canvas {
        id: progressRing
        anchors.fill: parent
        visible: root.focusRing
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.lineWidth = 2;
            ctx.strokeStyle = Theme.border.toString();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, Math.max(1, Math.min(width, height) / 2 - 2), 0, 2 * Math.PI);
            ctx.stroke();
            ctx.strokeStyle = Theme.accent.toString();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, Math.max(1, Math.min(width, height) / 2 - 2),
                -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * root.remaining);
            ctx.stroke();
        }
    }
    onRemainingChanged: progressRing.requestPaint()
    onFocusRingChanged: progressRing.requestPaint()
    SequentialAnimation on pulse {
        running: root.animate && root.privacy
        loops: Animation.Infinite
        NumberAnimation { to: 0.45; duration: 850; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 850; easing.type: Easing.InOutSine }
    }
    onAnimateChanged: { if (!root.animate) root.pulse = 1; }
}
