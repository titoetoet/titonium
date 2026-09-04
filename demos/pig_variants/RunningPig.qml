pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"

    property color headbandColor: "#FF4500"
    property color headbandStripeColor: "#FFFFFF"

    // Multi-angle perspective: "front" | "left" | "right" | "back"
    property string viewAngle: "front"

    property bool paused: false
    property bool sprintMode: false

    implicitWidth: 260
    implicitHeight: 250

    readonly property int runInterval: root.sprintMode ? 65 : 120
    property int runFrame: 0
    property real runBobY: 0
    property real runLegAngle: 0
    property real headTilt: 12

    Timer {
        interval: root.runInterval
        running: !root.paused
        repeat: true
        onTriggered: {
            root.runFrame = (root.runFrame + 1) % 4;
            switch (root.runFrame) {
            case 0:
                root.runLegAngle = 38;
                root.runBobY = -8;
                break;
            case 1:
                root.runLegAngle = 0;
                root.runBobY = 0;
                break;
            case 2:
                root.runLegAngle = -38;
                root.runBobY = -8;
                break;
            case 3:
                root.runLegAngle = 0;
                root.runBobY = 0;
                break;
            }

            if (Math.random() > (root.sprintMode ? 0.3 : 0.6)) {
                root.spawnDust();
            }
        }
    }

    function triggerSprint() {
        root.sprintMode = true;
        sprintTimer.restart();
    }

    Timer {
        id: sprintTimer
        interval: 3000
        onTriggered: root.sprintMode = false
    }

    function spawnDust() {
        let spawnX = root.width / 2;
        let dX = -(25 + Math.random() * 30);
        if (root.viewAngle === "left") {
            spawnX = root.width / 2 + 35;
            dX = 30 + Math.random() * 25;
        } else if (root.viewAngle === "right") {
            spawnX = root.width / 2 - 35;
            dX = -(30 + Math.random() * 25);
        } else if (root.viewAngle === "back") {
            spawnX = root.width / 2 + (Math.random() * 40 - 20);
            dX = (Math.random() * 40 - 20);
        } else {
            spawnX = root.width / 2 - 50 + (Math.random() * 16 - 8);
        }

        dustModel.append({
            symbol: root.sprintMode ? "💨" : "•",
            initX: spawnX,
            initY: root.height / 2 + 55,
            driftX: dX,
            col: root.sprintMode ? "#63B3ED" : "#A0AEC0"
        });
        if (dustModel.count > 10) {
            dustModel.remove(0);
        }
    }

    ListModel {
        id: dustModel
    }

    // Dust particles
    Repeater {
        model: dustModel
        delegate: Item {
            id: dustItem
            required property string symbol
            required property real initX
            required property real initY
            required property real driftX
            required property color col
            required property int index

            x: initX
            y: initY

            Text {
                text: dustItem.symbol
                font.bold: true
                font.pixelSize: dustItem.symbol === "💨" ? 16 : 14
                color: dustItem.col
            }

            NumberAnimation on x {
                from: dustItem.initX
                to: dustItem.initX + dustItem.driftX
                duration: 900
                easing.type: Easing.OutQuad
            }
            NumberAnimation on y {
                from: dustItem.initY
                to: dustItem.initY - 15
                duration: 900
                easing.type: Easing.OutQuad
            }
            NumberAnimation on opacity {
                from: 0.9
                to: 0.0
                duration: 900
                easing.type: Easing.InQuad
                onFinished: {
                    if (dustItem.index >= 0 && dustItem.index < dustModel.count) {
                        dustModel.remove(dustItem.index);
                    }
                }
            }
        }
    }

    // Main Pig Container
    Item {
        id: pigRoot
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.runBobY
        width: 170
        height: 190
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 70 } }

        // ==============================================================
        // 1. FRONT VIEW
        // ==============================================================
        Item {
            id: frontView
            anchors.fill: parent
            visible: root.viewAngle === "front"
            rotation: root.headTilt + (root.sprintMode ? 6 : 0)
            transformOrigin: Item.Bottom

            // Tail in wind
            Canvas {
                x: 8
                y: 120
                width: 36
                height: 24
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor;
                    ctx.lineWidth = 4;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.moveTo(32, 12);
                    ctx.quadraticCurveTo(18, 6, 2, 16);
                    ctx.stroke();
                }
            }

            // Left Leg
            Rectangle {
                x: 48
                y: 144
                width: 24
                height: 36
                radius: 11
                color: root.pigColor
                rotation: root.runLegAngle
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 18
                    height: 10
                    radius: 4
                    color: "#E53E3E"
                    border.color: "#FFFFFF"
                    border.width: 1
                }
            }

            // Right Leg
            Rectangle {
                x: 96
                y: 144
                width: 24
                height: 36
                radius: 11
                color: root.pigColor
                rotation: -root.runLegAngle
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 90; easing.type: Easing.InOutSine } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 18
                    height: 10
                    radius: 4
                    color: "#E53E3E"
                    border.color: "#FFFFFF"
                    border.width: 1
                }
            }

            // Body
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                width: 126
                height: 114
                radius: 57
                color: root.pigColor
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    width: 82
                    height: 72
                    radius: 36
                    color: Qt.lighter(root.pigColor, 1.08)
                }
            }

            // Arms
            Rectangle {
                x: 26
                y: 104
                width: 18
                height: 28
                radius: 9
                color: root.pigColor
                rotation: -root.runLegAngle * 1.1
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 90 } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12
                    height: 6
                    radius: 3
                    color: root.hoofColor
                }
            }
            Rectangle {
                x: 126
                y: 104
                width: 18
                height: 28
                radius: 9
                color: root.pigColor
                rotation: root.runLegAngle * 1.1
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 90 } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12
                    height: 6
                    radius: 3
                    color: root.hoofColor
                }
            }

            // Head with Headband
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                width: 112
                height: 98

                // Swept back ears
                Item {
                    x: 4; y: 4; width: 28; height: 34; rotation: -38; transformOrigin: Item.BottomRight
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath();
                            ctx.moveTo(8, 32); ctx.lineTo(2, 6); ctx.quadraticCurveTo(15, -2, 26, 22); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath();
                            ctx.moveTo(10, 26); ctx.lineTo(8, 12); ctx.quadraticCurveTo(15, 8, 20, 22); ctx.closePath(); ctx.fill();
                        }
                    }
                }
                Item {
                    x: 82; y: 4; width: 28; height: 34; rotation: 38; transformOrigin: Item.BottomLeft
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath();
                            ctx.moveTo(20, 32); ctx.lineTo(26, 6); ctx.quadraticCurveTo(15, -2, 2, 22); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath();
                            ctx.moveTo(18, 26); ctx.lineTo(20, 12); ctx.quadraticCurveTo(15, 8, 8, 22); ctx.closePath(); ctx.fill();
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 104
                    height: 88
                    radius: 44
                    color: root.pigColor
                }

                // Headband
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18
                    width: 102
                    height: 14
                    radius: 6
                    color: root.headbandColor
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: 3
                        color: root.headbandStripeColor
                    }
                }

                // Focused eyes
                Item {
                    x: 28; y: 38; width: 18; height: 16
                    Rectangle {
                        anchors.centerIn: parent
                        width: 13; height: 15; radius: 7; color: root.eyeColor
                        Rectangle { x: 3; y: 2; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }
                Item {
                    x: 66; y: 38; width: 18; height: 16
                    Rectangle {
                        anchors.centerIn: parent
                        width: 13; height: 15; radius: 7; color: root.eyeColor
                        Rectangle { x: 3; y: 2; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }

                // Sweat drop
                Text {
                    x: 88; y: 22; text: "💦"; font.pixelSize: 13
                }

                // Blush
                Rectangle { x: 16; y: 46; width: 16; height: 10; radius: 5; color: root.blushColor; opacity: 0.75 }
                Rectangle { x: 80; y: 46; width: 16; height: 10; radius: 5; color: root.blushColor; opacity: 0.75 }

                // Snout
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 12
                    width: 44
                    height: 30
                    radius: 15
                    color: root.snoutColor
                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 20
                        height: 5
                        radius: 2.5
                        color: "#50FFFFFF"
                    }
                    Rectangle { x: 11; y: 9; width: 6; height: 11; radius: 3; color: "#2B1B17" }
                    Rectangle { x: 27; y: 9; width: 6; height: 11; radius: 3; color: "#2B1B17" }
                }
            }
        }

        // ==============================================================
        // 2. ANGLED SPRINT VIEW (Nghiêng trái / Nghiêng phải)
        // ==============================================================
        Item {
            id: angledView
            anchors.fill: parent
            visible: root.viewAngle === "left" || root.viewAngle === "right"
            transform: Scale {
                xScale: root.viewAngle === "right" ? -1 : 1
                origin.x: angledView.width / 2
            }
            rotation: 16 + (root.sprintMode ? 8 : 0)
            transformOrigin: Item.Bottom

            // Tail blowing backwards
            Canvas {
                x: 132
                y: 110
                width: 36
                height: 20
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor;
                    ctx.lineWidth = 4.5;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.moveTo(2, 6);
                    ctx.quadraticCurveTo(18, 2, 34, 14);
                    ctx.stroke();
                }
            }

            // Headband tails fluttering behind
            Canvas {
                x: 108
                y: 18
                width: 42
                height: 24
                rotation: -root.runLegAngle * 0.4
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = root.headbandColor;
                    ctx.beginPath();
                    ctx.moveTo(2, 6);
                    ctx.quadraticCurveTo(20, -2, 38, 4);
                    ctx.lineTo(34, 12);
                    ctx.quadraticCurveTo(18, 6, 2, 10);
                    ctx.closePath();
                    ctx.fill();

                    ctx.beginPath();
                    ctx.moveTo(2, 10);
                    ctx.quadraticCurveTo(18, 14, 36, 20);
                    ctx.lineTo(32, 24);
                    ctx.quadraticCurveTo(16, 16, 2, 14);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // Back leg (kicking high behind)
            Rectangle {
                x: 106
                y: 138
                width: 22
                height: 38
                radius: 10
                color: root.pigColor
                rotation: -root.runLegAngle * 1.3
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 80 } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 18
                    height: 10
                    radius: 4
                    color: "#E53E3E"
                    border.color: "#FFFFFF"
                    border.width: 1
                }
            }

            // Front leg (striding forward)
            Rectangle {
                x: 44
                y: 138
                width: 24
                height: 38
                radius: 11
                color: root.pigColor
                rotation: root.runLegAngle * 1.3
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 80 } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 20
                    height: 10
                    radius: 4
                    color: "#E53E3E"
                    border.color: "#FFFFFF"
                    border.width: 1
                }
            }

            // Body
            Rectangle {
                x: 32
                y: 56
                width: 120
                height: 106
                radius: 53
                color: root.pigColor
                Rectangle {
                    x: 14
                    y: 18
                    width: 76
                    height: 70
                    radius: 35
                    color: Qt.lighter(root.pigColor, 1.08)
                }
            }

            // Arms pumping
            Rectangle {
                x: 18
                y: 92
                width: 18
                height: 30
                radius: 9
                color: root.pigColor
                rotation: -root.runLegAngle * 1.2
                transformOrigin: Item.Top
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12
                    height: 6
                    radius: 3
                    color: root.hoofColor
                }
            }
            Rectangle {
                x: 88
                y: 96
                width: 16
                height: 28
                radius: 8
                color: Qt.darker(root.pigColor, 1.05)
                rotation: root.runLegAngle * 1.2
                transformOrigin: Item.Top
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 10
                    height: 5
                    radius: 2.5
                    color: root.hoofColor
                }
            }

            // Angled Head
            Item {
                x: 12
                y: 10
                width: 108
                height: 94

                // Swept back ears
                Item {
                    x: 68
                    y: 6
                    width: 24
                    height: 32
                    rotation: 34
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = Qt.darker(root.pigColor, 1.08);
                            ctx.beginPath();
                            ctx.moveTo(18, 30); ctx.lineTo(24, 4); ctx.quadraticCurveTo(12, -2, 2, 20); ctx.closePath(); ctx.fill();
                        }
                    }
                }
                Item {
                    x: 10
                    y: 4
                    width: 26
                    height: 34
                    rotation: -28
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath();
                            ctx.moveTo(8, 32); ctx.lineTo(2, 6); ctx.quadraticCurveTo(15, -2, 26, 22); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath();
                            ctx.moveTo(10, 26); ctx.lineTo(8, 12); ctx.quadraticCurveTo(15, 8, 20, 22); ctx.closePath(); ctx.fill();
                        }
                    }
                }

                // Head circle
                Rectangle {
                    x: 8
                    y: 8
                    width: 94
                    height: 84
                    radius: 42
                    color: root.pigColor
                }

                // Headband angled
                Rectangle {
                    x: 6
                    y: 18
                    width: 92
                    height: 13
                    radius: 5
                    color: root.headbandColor
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 6
                        height: 3
                        color: root.headbandStripeColor
                    }
                }

                // Eyes focused
                Item {
                    x: 22
                    y: 38
                    width: 14
                    height: 15
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 14; radius: 6; color: root.eyeColor
                        Rectangle { x: 2; y: 2; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }

                // Blush
                Rectangle { x: 12; y: 48; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.75 }

                // Snout (Profile shifted forward left)
                Rectangle {
                    x: 0
                    y: 46
                    width: 36
                    height: 26
                    radius: 13
                    color: root.snoutColor
                    Rectangle {
                        anchors.top: parent.top; anchors.topMargin: 2
                        x: 6; width: 16; height: 4; radius: 2; color: "#50FFFFFF"
                    }
                    Rectangle { x: 7; y: 8; width: 5; height: 9; radius: 2.5; color: "#2B1B17" }
                    Rectangle { x: 19; y: 8; width: 4; height: 8; radius: 2; color: "#2B1B17"; opacity: 0.5 }
                }
            }
        }

        // ==============================================================
        // 3. BACK VIEW (Running away from camera)
        // ==============================================================
        Item {
            id: backView
            anchors.fill: parent
            visible: root.viewAngle === "back"
            rotation: Math.sin(root.runLegAngle * 0.05) * 6
            transformOrigin: Item.Bottom

            // Left leg kicking showing red shoe sole
            Rectangle {
                x: 46
                y: 140
                width: 24
                height: 36
                radius: 11
                color: root.pigColor
                rotation: root.runLegAngle * 1.2
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 80 } }

                // Shoe sole from behind
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 20
                    height: 10
                    radius: 4
                    color: "#FFFFFF" // White rubber sole
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: 5
                        color: "#E53E3E" // Red shoe heel
                    }
                }
            }

            // Right leg kicking
            Rectangle {
                x: 100
                y: 140
                width: 24
                height: 36
                radius: 11
                color: root.pigColor
                rotation: -root.runLegAngle * 1.2
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 80 } }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 20
                    height: 10
                    radius: 4
                    color: "#FFFFFF"
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: 5
                        color: "#E53E3E"
                    }
                }
            }

            // Piggy Rear / Buttocks swaying with stride
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 52
                width: 130
                height: 110
                radius: 55
                color: root.pigColor

                // Butt crease line
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Qt.darker(root.pigColor, 1.1);
                        ctx.lineWidth = 2.5;
                        ctx.beginPath();
                        ctx.moveTo(width / 2, 70);
                        ctx.lineTo(width / 2, 95);
                        ctx.stroke();
                    }
                }

                // Fast wagging tail in center
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 32
                    width: 32
                    height: 32
                    rotation: Math.sin(root.runFrame * 1.5) * 32

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = root.pigColor;
                            ctx.lineWidth = 4.5;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.arc(16, 16, 9, 0.2 * Math.PI, 1.8 * Math.PI, false);
                            ctx.stroke();
                        }
                    }
                }
            }

            // Head (Back of Head)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: 108
                height: 92

                // Ears back
                Item {
                    x: 6; y: 4; width: 28; height: 32; rotation: -35
                    Rectangle { anchors.fill: parent; radius: 14; color: root.pigColor }
                }
                Item {
                    x: 74; y: 4; width: 28; height: 32; rotation: 35
                    Rectangle { anchors.fill: parent; radius: 14; color: root.pigColor }
                }

                // Head circle
                Rectangle {
                    anchors.centerIn: parent
                    width: 102
                    height: 86
                    radius: 43
                    color: root.pigColor
                }

                // Headband wrapping back of head
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18
                    width: 98
                    height: 14
                    radius: 6
                    color: root.headbandColor
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 6
                        height: 3
                        color: root.headbandStripeColor
                    }
                }

                // Tied knot and fluttering ribbon tails
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 28
                    width: 24
                    height: 24
                    rotation: Math.sin(root.runFrame) * 20

                    // Knot circle
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        radius: 5
                        color: Qt.darker(root.headbandColor, 1.15)
                    }

                    // Left ribbon
                    Rectangle {
                        x: 0; y: 6; width: 14; height: 6; radius: 3; color: root.headbandColor; rotation: 25
                    }
                    // Right ribbon
                    Rectangle {
                        x: 10; y: 6; width: 14; height: 6; radius: 3; color: root.headbandColor; rotation: -25
                    }
                }
            }
        }
    }

    // Mouse area
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggerSprint()
    }
}
