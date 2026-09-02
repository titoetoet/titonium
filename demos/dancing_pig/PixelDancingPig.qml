pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property int pixel: 8
    property int bpm: 130
    property string danceMode: "disco" // "disco", "hop"
    property real bounceDistance: 20
    property real walkDistance: 75
    property real bounceY: 0
    property int frame: 0

    readonly property var colorPalette: [
        "#00000000", // 0: transparent
        "#FFB6C1",   // 1: light pink body
        "#FF69B4",   // 2: deep pink ears/snout
        "#2B1B17",   // 3: dark eyes/hooves
        "#FFFFFF",   // 4: white sparkle
        "#FF3366",   // 5: blush
        "#FFD700"    // 6: gold crown
    ]

    // 4 frames of dancing pig pixel art (16x16)
    readonly property var frames: [
        // Frame 0: Standing ready, neutral
        [
            0,0,2,2,0,0,0,0,0,0,0,0,2,2,0,0,
            0,2,1,1,2,0,0,0,0,0,0,2,1,1,2,0,
            0,2,1,1,1,1,1,1,1,1,1,1,1,1,2,0,
            0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,
            0,0,1,3,4,1,1,1,1,1,1,3,4,1,0,0,
            0,0,1,3,3,1,1,1,1,1,1,3,3,1,0,0,
            0,5,1,1,2,2,2,2,2,2,1,1,5,0,0,0,
            0,5,1,2,2,3,2,2,3,2,2,1,5,0,0,0,
            0,0,1,2,2,2,2,2,2,2,2,1,0,0,0,0,
            0,2,1,1,1,1,1,1,1,1,1,1,1,2,0,0,
            2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,
            3,0,1,1,1,1,1,1,1,1,1,1,1,0,3,0,
            0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,
            0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,
            0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,
            0,0,0,3,3,3,0,0,0,3,3,3,0,0,0,0
        ],
        // Frame 1: Left step & left arm waving up (Disco!)
        [
            0,2,2,0,0,0,0,0,0,0,0,0,0,2,2,0,
            2,1,1,2,0,0,0,0,0,0,0,0,2,1,1,2,
            2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,
            0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
            0,1,1,3,4,1,1,1,1,1,1,3,4,1,0,0,
            0,1,1,3,3,1,1,1,1,1,1,3,3,1,0,0,
            3,5,1,1,2,2,2,2,2,2,1,1,5,0,0,0,
            0,3,1,2,2,3,2,2,3,2,2,1,5,0,0,0,
            0,0,2,2,2,2,2,2,2,2,2,1,0,0,0,0,
            0,0,1,2,1,1,1,1,1,1,1,1,1,2,0,0,
            0,1,1,1,1,1,1,1,1,1,1,1,1,1,2,0,
            0,1,1,1,1,1,1,1,1,1,1,1,1,0,3,0,
            0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,
            0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,
            3,3,3,0,0,0,0,0,0,0,1,1,1,0,0,0,
            0,0,0,0,0,0,0,0,0,0,3,3,3,0,0,0
        ],
        // Frame 2: Mid-air bounce, both hands UP, happy eyes!
        [
            0,2,2,0,0,0,6,6,6,0,0,0,0,2,2,0,
            2,1,1,2,0,0,0,6,0,0,0,0,2,1,1,2,
            2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,
            3,1,1,1,1,1,1,1,1,1,1,1,1,1,1,3,
            0,3,1,3,3,1,1,1,1,1,1,3,3,1,3,0,
            0,0,3,1,1,3,1,1,1,1,3,1,1,3,0,0,
            0,5,1,1,2,2,2,2,2,2,1,1,5,0,0,0,
            0,5,1,2,2,3,2,2,3,2,2,1,5,0,0,0,
            0,0,1,2,2,2,2,2,2,2,2,1,0,0,0,0,
            0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,
            0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,
            0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,
            0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,
            0,0,0,1,1,0,0,0,0,0,1,1,0,0,0,0,
            0,0,3,3,0,0,0,0,0,0,0,3,3,0,0,0,
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        ],
        // Frame 3: Right step & right arm waving up (Disco point right!)
        [
            0,0,2,2,0,0,0,0,0,0,0,0,0,2,2,0,
            0,2,1,1,2,0,0,0,0,0,0,0,2,1,1,2,
            0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,
            0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
            0,0,1,3,4,1,1,1,1,1,1,3,4,1,1,0,
            0,0,1,3,3,1,1,1,1,1,1,3,3,1,1,0,
            0,0,0,5,1,1,2,2,2,2,2,2,1,1,5,3,
            0,0,0,5,1,2,2,3,2,2,3,2,2,1,3,0,
            0,0,0,0,1,2,2,2,2,2,2,2,2,2,0,0,
            0,0,2,1,1,1,1,1,1,1,1,1,2,1,0,0,
            0,2,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
            0,3,0,1,1,1,1,1,1,1,1,1,1,1,1,0,
            0,0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,
            0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,
            0,0,0,1,1,1,0,0,0,0,0,0,0,3,3,3,
            0,0,0,3,3,3,0,0,0,0,0,0,0,0,0,0
        ]
    ]

    readonly property int beatDuration: Math.max(120, Math.round(60000 / root.bpm))

    Timer {
        interval: Math.round(root.beatDuration / 2)
        running: true
        repeat: true
        onTriggered: {
            root.frame = (root.frame + 1) % root.frames.length;
            pixelCanvas.requestPaint();
        }
    }

    SequentialAnimation on bounceY {
        running: true
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: -root.bounceDistance; duration: Math.round(root.beatDuration * 0.45); easing.type: Easing.OutQuad }
        NumberAnimation { from: -root.bounceDistance; to: 0; duration: Math.round(root.beatDuration * 0.55); easing.type: Easing.OutBounce }
    }

    property real walkX: 0
    property real facingDirection: 1.0

    SequentialAnimation {
        id: walkAnimation
        running: root.danceMode === "walk"
        loops: Animation.Infinite

        ScriptAction { script: root.facingDirection = 1.0; }
        NumberAnimation {
            target: root
            property: "walkX"
            from: -root.walkDistance
            to: root.walkDistance
            duration: Math.round(root.beatDuration * 7)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 200 }
        ScriptAction { script: root.facingDirection = -1.0; }
        PauseAnimation { duration: 200 }

        NumberAnimation {
            target: root
            property: "walkX"
            from: root.walkDistance
            to: -root.walkDistance
            duration: Math.round(root.beatDuration * 7)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 200 }
        ScriptAction { script: root.facingDirection = 1.0; }
        PauseAnimation { duration: 200 }
    }

    onDanceModeChanged: {
        if (root.danceMode === "walk") {
            root.walkX = -root.walkDistance;
            walkAnimation.restart();
        } else {
            walkAnimation.stop();
            root.walkX = 0;
            root.facingDirection = 1.0;
        }
    }

    implicitWidth: 16 * root.pixel
    implicitHeight: 16 * root.pixel

    Canvas {
        id: pixelCanvas
        x: (parent.width - width) / 2 + root.walkX
        y: (parent.height - height) / 2 + root.bounceY
        width: 16 * root.pixel
        height: 16 * root.pixel
        transform: Scale {
            xScale: root.facingDirection
            origin.x: (16 * root.pixel) / 2
        }
        Behavior on x { enabled: root.danceMode !== "walk"; NumberAnimation { duration: 300 } }

        onPaint: {
            const ctx = pixelCanvas.getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const currentFrame = root.frames[root.frame % root.frames.length];
            const pSize = root.pixel;

            for (let r = 0; r < 16; r++) {
                for (let c = 0; c < 16; c++) {
                    const colorIndex = currentFrame[r * 16 + c];
                    if (colorIndex > 0 && colorIndex < root.colorPalette.length) {
                        ctx.fillStyle = root.colorPalette[colorIndex];
                        ctx.fillRect(c * pSize, r * pSize, pSize, pSize);
                    }
                }
            }
        }
    }
}
