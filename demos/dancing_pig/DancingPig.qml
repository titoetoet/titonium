pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property int pixelSize: 8
    property int bpm: 130
    property string danceStyle: "disco" // "disco", "hop", "wiggle"
    property real walkDistance: 75
    property bool showNotes: true
    property bool showHearts: true
    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"
    property bool showShadow: false
    property bool paused: false

    onPausedChanged: {
        if (!root.paused)
            return;
        root.frameIndex = 0;
        root.bounceY = 0;
        root.tiltAngle = 0;
        root.earFlap = 0;
        root.tailWag = 0;
        root.walkX = 0;
        root.facingDirection = 1.0;
    }

    // Beat duration in milliseconds
    readonly property int beatDuration: Math.max(150, Math.round(60000 / root.bpm))
    property int frameIndex: 0
    property real bounceY: 0
    property real tiltAngle: 0
    property real earFlap: 0
    property real tailWag: 0

    implicitWidth: 260
    implicitHeight: 300

    // Frame ticker based on BPM
    Timer {
        id: beatTimer
        interval: Math.round(root.beatDuration / 2)
        running: !root.paused
        repeat: true
        onTriggered: {
            root.frameIndex = (root.frameIndex + 1) % 4;
            if (root.showNotes && Math.random() > 0.4) {
                root.spawnNote();
            }
        }
    }

    property real walkX: 0
    property real facingDirection: 1.0

    // Walking back and forth across the stage
    SequentialAnimation {
        id: walkAnimation
        running: root.danceStyle === "walk" && !root.paused
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

    onDanceStyleChanged: {
        if (root.danceStyle === "walk") {
            root.walkX = -root.walkDistance;
            walkAnimation.restart();
        } else {
            walkAnimation.stop();
            root.walkX = 0;
            root.facingDirection = 1.0;
        }
    }

    // Bounce animation on Y axis
    SequentialAnimation on bounceY {
        running: !root.paused
        loops: Animation.Infinite
        NumberAnimation {
            from: 0
            to: root.danceStyle === "hop" ? -35 : (root.danceStyle === "walk" ? -10 : -16)
            duration: Math.round(root.beatDuration * 0.45)
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            from: root.danceStyle === "hop" ? -35 : (root.danceStyle === "walk" ? -10 : -16)
            to: 0
            duration: Math.round(root.beatDuration * 0.55)
            easing.type: Easing.OutBounce
        }
    }

    // Body rocking tilt angle
    SequentialAnimation on tiltAngle {
        running: root.danceStyle !== "hop" && !root.paused
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: -10; duration: root.beatDuration; easing.type: Easing.InOutSine }
        NumberAnimation { from: -10; to: 10; duration: root.beatDuration * 2; easing.type: Easing.InOutSine }
        NumberAnimation { from: 10; to: 0; duration: root.beatDuration; easing.type: Easing.InOutSine }
    }

    // Ear flapper
    SequentialAnimation on earFlap {
        running: !root.paused
        loops: Animation.Infinite
        NumberAnimation { from: -8; to: 12; duration: Math.round(root.beatDuration * 0.8); easing.type: Easing.InOutQuad }
        NumberAnimation { from: 12; to: -8; duration: Math.round(root.beatDuration * 0.8); easing.type: Easing.InOutQuad }
    }

    // Tail wagging
    SequentialAnimation on tailWag {
        running: !root.paused
        loops: Animation.Infinite
        NumberAnimation { from: -20; to: 20; duration: Math.round(root.beatDuration * 0.4); easing.type: Easing.InOutSine }
        NumberAnimation { from: 20; to: -20; duration: Math.round(root.beatDuration * 0.4); easing.type: Easing.InOutSine }
    }

    // Bouncing shadow on the dance floor (optional, hidden by default)
    Rectangle {
        id: shadow
        visible: root.showShadow
        x: (parent.width - width) / 2 + root.walkX
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 15
        width: Math.max(50, 110 + root.bounceY * 1.2)
        height: Math.max(10, 24 + root.bounceY * 0.3)
        radius: width / 2
        color: "#28000000"
        opacity: Math.max(0.2, 0.6 + root.bounceY * 0.015)
        Behavior on width { NumberAnimation { duration: 60 } }
        Behavior on x { enabled: root.danceStyle !== "walk"; NumberAnimation { duration: 300 } }
    }

    // Musical notes & hearts container
    Item {
        id: particlesContainer
        anchors.fill: parent
    }

    Component {
        id: noteComponent
        Text {
            id: note
            property real targetY: y - (60 + Math.random() * 70)
            property real targetX: x + (Math.random() - 0.5) * 60

            ParallelAnimation {
                running: true
                NumberAnimation { target: note; property: "y"; to: note.targetY; duration: 1100; easing.type: Easing.OutQuad }
                NumberAnimation { target: note; property: "x"; to: note.targetX; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { target: note; property: "opacity"; from: 1; to: 0; duration: 1100 }
                NumberAnimation { target: note; property: "scale"; from: 0.6; to: 1.4; duration: 1100 }
                onFinished: note.destroy()
            }
        }
    }

    function spawnNote() {
        const noteChars = ["🎵", "🎶", "🎼", "✨", "💖", "⭐"];
        const char = noteChars[Math.floor(Math.random() * noteChars.length)];
        noteComponent.createObject(particlesContainer, {
            text: char,
            font: { pixelSize: Math.floor(Math.random() * 10 + 18) },
            color: Qt.hsla(Math.random(), 0.9, 0.65, 1.0),
            x: root.width / 2 + (Math.random() - 0.5) * 120,
            y: root.height / 2 + root.bounceY + (Math.random() - 0.5) * 40,
            opacity: 1.0
        });
    }

    function cheer() {
        for (let i = 0; i < 12; i++) {
            spawnNote();
        }
    }

    // Pig Mascot Container
    Item {
        id: pigRoot
        x: (parent.width - width) / 2 + root.walkX
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: 160
        height: 190
        y: root.bounceY
        rotation: root.tiltAngle
        transformOrigin: Item.Bottom
        transform: Scale {
            xScale: root.facingDirection
            origin.x: pigRoot.width / 2
        }
        Behavior on x { enabled: root.danceStyle !== "walk"; NumberAnimation { duration: 300 } }

        // 1. Curly Spring Tail
        Canvas {
            id: tailCanvas
            x: 18
            y: 110
            width: 36
            height: 36
            rotation: root.tailWag
            transformOrigin: Item.Right
            onPaint: {
                const ctx = tailCanvas.getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = root.pigColor;
                ctx.lineWidth = 4.5;
                ctx.lineCap = "round";
                ctx.beginPath();
                // Spiral curly pig tail
                ctx.arc(18, 18, 11, 0, Math.PI * 1.6, false);
                ctx.arc(14, 15, 6, 0, Math.PI * 1.5, false);
                ctx.stroke();
            }
        }

        // 2. Left Dancing Leg
        Rectangle {
            id: leftLeg
            x: 42
            y: 145 + (root.danceStyle === "walk" ? (root.frameIndex % 2 === 0 ? -6 : 6) : (root.frameIndex === 1 ? -12 : (root.frameIndex === 3 ? 4 : 0)))
            width: 28
            height: 36
            radius: 12
            color: root.pigColor
            rotation: root.danceStyle === "walk" ? (root.frameIndex % 2 === 0 ? 30 : -30) : (root.frameIndex === 1 ? -22 : 0)
            transformOrigin: Item.Top
            Behavior on rotation { NumberAnimation { duration: 110 } }
            Behavior on y { NumberAnimation { duration: 110 } }

            // Hoof
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 10
                radius: 4
                color: root.hoofColor
            }
        }

        // 3. Right Dancing Leg
        Rectangle {
            id: rightLeg
            x: 90
            y: 145 + (root.danceStyle === "walk" ? (root.frameIndex % 2 === 0 ? 6 : -6) : (root.frameIndex === 3 ? -12 : (root.frameIndex === 1 ? 4 : 0)))
            width: 28
            height: 36
            radius: 12
            color: root.pigColor
            rotation: root.danceStyle === "walk" ? (root.frameIndex % 2 === 0 ? -30 : 30) : (root.frameIndex === 3 ? 22 : 0)
            transformOrigin: Item.Top
            Behavior on rotation { NumberAnimation { duration: 110 } }
            Behavior on y { NumberAnimation { duration: 110 } }

            // Hoof
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 10
                radius: 4
                color: root.hoofColor
            }
        }

        // 4. Chubby Body (Torso)
        Rectangle {
            id: body
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 24
            width: 126
            height: 112
            radius: 56
            color: root.pigColor
            scale: root.bounceY < -15 ? 0.94 : (root.bounceY === 0 ? 1.05 : 1.0)
            Behavior on scale { NumberAnimation { duration: 100 } }

            // Belly patch (softer light pink)
            Rectangle {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 10
                width: 78
                height: 68
                radius: 36
                color: Qt.lighter(root.pigColor, 1.08)
            }
        }

        // 5. Left Dancing Arm (Hoof)
        Rectangle {
            id: leftArm
            x: 14
            y: 86
            width: 24
            height: 48
            radius: 12
            color: root.pigColor
            transformOrigin: Item.TopRight
            // Dance swinging moves
            rotation: {
                if (root.danceStyle === "walk") return (root.frameIndex % 2 === 0 ? -35 : 25);
                if (root.frameIndex === 1) return -120; // Disco point up!
                if (root.frameIndex === 2) return -90;  // Wave out!
                if (root.frameIndex === 3) return -35;  // Low swing
                return -55;
            }
            Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

            // Hoof tip
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 9
                radius: 4
                color: root.hoofColor
            }
        }

        // 6. Right Dancing Arm (Hoof)
        Rectangle {
            id: rightArm
            x: 122
            y: 86
            width: 24
            height: 48
            radius: 12
            color: root.pigColor
            transformOrigin: Item.TopLeft
            // Dance swinging moves
            rotation: {
                if (root.danceStyle === "walk") return (root.frameIndex % 2 === 0 ? 25 : -35);
                if (root.frameIndex === 3) return 120; // Disco point up!
                if (root.frameIndex === 2) return 90;  // Wave out!
                if (root.frameIndex === 1) return 35;  // Low swing
                return 55;
            }
            Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

            // Hoof tip
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 9
                radius: 4
                color: root.hoofColor
            }
        }

        // 7. Pig Head
        Item {
            id: headGroup
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 120
            height: 104

            // Left Ear
            Item {
                x: 8
                y: -10
                width: 32
                height: 38
                rotation: -18 + root.earFlap
                transformOrigin: Item.BottomRight

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = root.pigColor;
                        ctx.beginPath();
                        ctx.moveTo(8, 36);
                        ctx.lineTo(2, 6);
                        ctx.quadraticCurveTo(16, -2, 30, 24);
                        ctx.closePath();
                        ctx.fill();

                        // Inner ear pink
                        ctx.fillStyle = root.snoutColor;
                        ctx.beginPath();
                        ctx.moveTo(11, 30);
                        ctx.lineTo(8, 12);
                        ctx.quadraticCurveTo(16, 8, 24, 24);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }

            // Right Ear
            Item {
                x: 80
                y: -10
                width: 32
                height: 38
                rotation: 18 - root.earFlap
                transformOrigin: Item.BottomLeft

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = root.pigColor;
                        ctx.beginPath();
                        ctx.moveTo(24, 36);
                        ctx.lineTo(30, 6);
                        ctx.quadraticCurveTo(16, -2, 2, 24);
                        ctx.closePath();
                        ctx.fill();

                        // Inner ear pink
                        ctx.fillStyle = root.snoutColor;
                        ctx.beginPath();
                        ctx.moveTo(21, 30);
                        ctx.lineTo(24, 12);
                        ctx.quadraticCurveTo(16, 8, 8, 24);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }

            // Head Main Circle
            Rectangle {
                anchors.centerIn: parent
                width: 108
                height: 94
                radius: 50
                color: root.pigColor
            }

            // Left Eye
            Item {
                x: 32
                y: 34
                width: 14
                height: 18

                // Open eye
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.eyeColor
                    visible: root.frameIndex !== 2 // Blink on frame 2

                    // Eye glint
                    Rectangle {
                        x: 3
                        y: 3
                        width: 5
                        height: 5
                        radius: 2.5
                        color: "#FFFFFF"
                    }
                }

                // Happy blinking curve ^
                Canvas {
                    anchors.fill: parent
                    visible: root.frameIndex === 2
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = root.eyeColor;
                        ctx.lineWidth = 3.5;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.arc(7, 12, 6, Math.PI, 0, false);
                        ctx.stroke();
                    }
                }
            }

            // Right Eye
            Item {
                x: 74
                y: 34
                width: 14
                height: 18

                // Open eye
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.eyeColor
                    visible: root.frameIndex !== 2

                    // Eye glint
                    Rectangle {
                        x: 3
                        y: 3
                        width: 5
                        height: 5
                        radius: 2.5
                        color: "#FFFFFF"
                    }
                }

                // Happy blinking curve ^
                Canvas {
                    anchors.fill: parent
                    visible: root.frameIndex === 2
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = root.eyeColor;
                        ctx.lineWidth = 3.5;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.arc(7, 12, 6, Math.PI, 0, false);
                        ctx.stroke();
                    }
                }
            }

            // Left Blush
            Rectangle {
                x: 18
                y: 54
                width: 18
                height: 11
                radius: 6
                color: root.blushColor
                opacity: 0.65
            }

            // Right Blush
            Rectangle {
                x: 84
                y: 54
                width: 18
                height: 11
                radius: 6
                color: root.blushColor
                opacity: 0.65
            }

            // Pig Snout (The iconic round pink nose!)
            Rectangle {
                id: snout
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 16
                width: 48
                height: 34
                radius: 17
                color: root.snoutColor

                // Snout highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 24
                    height: 6
                    radius: 3
                    color: "#50FFFFFF"
                }

                // Left Nostril
                Rectangle {
                    x: 12
                    y: 11
                    width: 7
                    height: 12
                    radius: 3.5
                    color: root.hoofColor
                }

                // Right Nostril
                Rectangle {
                    x: 29
                    y: 11
                    width: 7
                    height: 12
                    radius: 3.5
                    color: root.hoofColor
                }
            }

            // Cute Happy Mouth
            Canvas {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 78
                width: 24
                height: 12
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.eyeColor;
                    ctx.lineWidth = 3;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(12, 3, 7, 0.2, Math.PI - 0.2, false);
                    ctx.stroke();
                }
            }
        }
    }

    // Tap to cheer/bounce
    MouseArea {
        anchors.fill: parent
        onClicked: root.cheer()
    }
}
