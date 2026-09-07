pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"

    property color backpackColor: "#4FD1C5"
    property color strapColor: "#319795"

    // Multi-angle perspective: "front" | "left" | "right" | "back"
    property string viewAngle: "front"

    property bool paused: false
    property bool waving: false

    implicitWidth: 260
    implicitHeight: 250

    // Walking stride & step ticker
    property int stepFrame: 0
    property real bobY: 0
    property real legAngle: 0
    property real earSwing: 0

    Timer {
        interval: 180
        running: !root.paused
        repeat: true
        onTriggered: {
            root.stepFrame = (root.stepFrame + 1) % 4;
            switch (root.stepFrame) {
            case 0:
                root.legAngle = 24;
                root.bobY = -5;
                root.earSwing = 6;
                break;
            case 1:
                root.legAngle = 0;
                root.bobY = 0;
                root.earSwing = 0;
                break;
            case 2:
                root.legAngle = -24;
                root.bobY = -5;
                root.earSwing = -6;
                break;
            case 3:
                root.legAngle = 0;
                root.bobY = 0;
                root.earSwing = 0;
                break;
            }

            if (Math.random() > 0.5) {
                root.spawnMusicNote();
            }
        }
    }

    function triggerWave() {
        if (root.waving)
            return;
        root.waving = true;
        waveTimer.restart();
    }

    Timer {
        id: waveTimer
        interval: 2400
        onTriggered: root.waving = false
    }

    function spawnMusicNote() {
        const notes = ["♪", "♫", "♬", "♩"];
        const chosen = notes[Math.floor(Math.random() * notes.length)];
        let initX = root.width / 2 + 25;
        let dX = 20 + Math.random() * 20;
        if (root.viewAngle === "left") {
            initX = root.width / 2 - 25;
            dX = -(20 + Math.random() * 20);
        } else if (root.viewAngle === "back") {
            initX = root.width / 2 + (Math.random() * 30 - 15);
            dX = (Math.random() * 30 - 15);
        }

        musicModel.append({
            symbol: chosen,
            initX: initX,
            initY: root.height / 2 - 35,
            driftX: dX,
            col: (Math.random() > 0.5 ? "#ED64A6" : "#4FD1C5")
        });
        if (musicModel.count > 8) {
            musicModel.remove(0);
        }
    }

    ListModel {
        id: musicModel
    }

    // Floating musical notes
    Repeater {
        model: musicModel
        delegate: Item {
            id: noteItem
            required property string symbol
            required property real initX
            required property real initY
            required property real driftX
            required property color col
            required property int index

            x: initX
            y: initY

            Text {
                text: noteItem.symbol
                font.bold: true
                font.pixelSize: 15
                color: noteItem.col
            }

            NumberAnimation on y {
                from: noteItem.initY
                to: noteItem.initY - 60
                duration: 1500
                easing.type: Easing.OutCubic
            }
            NumberAnimation on x {
                from: noteItem.initX
                to: noteItem.initX + noteItem.driftX
                duration: 1500
                easing.type: Easing.InOutSine
            }
            NumberAnimation on opacity {
                from: 1.0
                to: 0.0
                duration: 1500
                easing.type: Easing.InQuad
                onFinished: {
                    if (noteItem.index >= 0 && noteItem.index < musicModel.count) {
                        musicModel.remove(noteItem.index);
                    }
                }
            }
        }
    }

    // Main Pig Body Container
    Item {
        id: pigRoot
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.bobY
        width: 170
        height: 190
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 120; easing.type: Easing.OutSine } }

        // ==============================================================
        // 1. FRONT VIEW
        // ==============================================================
        Item {
            id: frontView
            anchors.fill: parent
            visible: root.viewAngle === "front"

            // Tail
            Canvas {
                x: 12
                y: 115
                width: 32
                height: 32
                rotation: root.earSwing * 2
                transformOrigin: Item.Right
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor;
                    ctx.lineWidth = 4;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(16, 16, 10, 0, Math.PI * 1.5, false);
                    ctx.stroke();
                }
            }

            // Backpack on side
            Rectangle {
                x: 20
                y: 90
                width: 28
                height: 48
                radius: 12
                color: root.backpackColor
                border.color: root.strapColor
                border.width: 2
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 20
                    radius: 6
                    color: Qt.darker(root.backpackColor, 1.15)
                }
            }

            // Left Leg
            Rectangle {
                x: 52
                y: 146
                width: 24
                height: 34
                radius: 10
                color: root.pigColor
                rotation: root.legAngle
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.InOutSine } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 8
                    radius: 4
                    color: root.hoofColor
                }
            }

            // Right Leg
            Rectangle {
                x: 94
                y: 146
                width: 24
                height: 34
                radius: 10
                color: root.pigColor
                rotation: -root.legAngle
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.InOutSine } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 8
                    radius: 4
                    color: root.hoofColor
                }
            }

            // Body
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 26
                width: 128
                height: 110
                radius: 55
                color: root.pigColor

                // Straps on front
                Rectangle { x: 26; y: 16; width: 6; height: 50; radius: 3; color: root.strapColor }
                Rectangle { x: 96; y: 16; width: 6; height: 50; radius: 3; color: root.strapColor }

                // Belly
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    width: 80
                    height: 70
                    radius: 35
                    color: Qt.lighter(root.pigColor, 1.08)
                }
            }

            // Arms
            Rectangle {
                x: 28
                y: 106
                width: 18
                height: 26
                radius: 9
                color: root.pigColor
                rotation: -root.legAngle * 0.8
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
                x: 124
                y: 106
                width: 18
                height: 26
                radius: 9
                color: root.pigColor
                rotation: root.waving ? (Math.sin(root.earSwing * 1.5) * 25 - 45) : (root.legAngle * 0.8)
                transformOrigin: Item.Top
                Behavior on rotation { NumberAnimation { duration: 150 } }
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 12
                    height: 6
                    radius: 3
                    color: root.hoofColor
                }
            }

            // Head
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: 110
                height: 96

                Item {
                    x: 6; y: -4 + root.earSwing; width: 30; height: 34; rotation: -26; transformOrigin: Item.BottomRight
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath();
                            ctx.moveTo(8, 32); ctx.lineTo(2, 6); ctx.quadraticCurveTo(15, -2, 28, 22); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath();
                            ctx.moveTo(10, 26); ctx.lineTo(8, 12); ctx.quadraticCurveTo(15, 8, 22, 22); ctx.closePath(); ctx.fill();
                        }
                    }
                }
                Item {
                    x: 74; y: -4 - root.earSwing; width: 30; height: 34; rotation: 26; transformOrigin: Item.BottomLeft
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath();
                            ctx.moveTo(22, 32); ctx.lineTo(28, 6); ctx.quadraticCurveTo(15, -2, 2, 22); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath();
                            ctx.moveTo(20, 26); ctx.lineTo(22, 12); ctx.quadraticCurveTo(15, 8, 8, 22); ctx.closePath(); ctx.fill();
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 102
                    height: 88
                    radius: 44
                    color: root.pigColor
                }

                // Eyes
                Item {
                    x: 28; y: 38; width: 18; height: 16
                    Rectangle {
                        anchors.centerIn: parent
                        width: 13; height: 15; radius: 7; color: root.eyeColor
                        Rectangle { x: 3; y: 2; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }
                Item {
                    x: 64; y: 38; width: 18; height: 16
                    Rectangle {
                        anchors.centerIn: parent
                        width: 13; height: 15; radius: 7; color: root.eyeColor
                        Rectangle { x: 3; y: 2; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }

                Rectangle { x: 16; y: 46; width: 16; height: 10; radius: 5; color: root.blushColor; opacity: 0.65 }
                Rectangle { x: 78; y: 46; width: 16; height: 10; radius: 5; color: root.blushColor; opacity: 0.65 }

                // Snout
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 12
                    width: 44
                    height: 30
                    radius: 15
                    color: root.snoutColor
                    Rectangle {
                        anchors.top: parent.top; anchors.topMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 20; height: 5; radius: 2.5; color: "#50FFFFFF"
                    }
                    Rectangle { x: 11; y: 9; width: 6; height: 11; radius: 3; color: "#2B1B17" }
                    Rectangle { x: 27; y: 9; width: 6; height: 11; radius: 3; color: "#2B1B17" }
                }

                // Whistling mouth
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 74
                    width: 6
                    height: 6
                    radius: 3
                    color: "#2B1B17"
                }
            }
        }

        // ==============================================================
        // 2. ANGLED 3/4 STROLL VIEW (Nghiêng trái / Nghiêng phải)
        // ==============================================================
        Item {
            id: angledView
            anchors.fill: parent
            visible: root.viewAngle === "left" || root.viewAngle === "right"
            transform: Scale {
                xScale: root.viewAngle === "right" ? -1 : 1
                origin.x: angledView.width / 2
            }

            // Backpack on right/back side
            Rectangle {
                x: 122
                y: 78
                width: 30
                height: 52
                radius: 12
                color: root.backpackColor
                border.color: root.strapColor
                border.width: 2
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 22
                    radius: 6
                    color: Qt.darker(root.backpackColor, 1.15)
                }
            }

            // Tail below backpack
            Canvas {
                x: 130
                y: 118
                width: 30
                height: 30
                rotation: root.earSwing * 2
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor;
                    ctx.lineWidth = 4;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(15, 15, 9, 0.3 * Math.PI, 1.8 * Math.PI, false);
                    ctx.stroke();
                }
            }

            // Back leg
            Rectangle {
                x: 94
                y: 144
                width: 22
                height: 34
                radius: 10
                color: Qt.darker(root.pigColor, 1.05)
                rotation: -root.legAngle * 1.1
                transformOrigin: Item.Top
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 7
                    radius: 3.5
                    color: root.hoofColor
                }
            }

            // Front leg
            Rectangle {
                x: 52
                y: 144
                width: 24
                height: 34
                radius: 10
                color: root.pigColor
                rotation: root.legAngle * 1.1
                transformOrigin: Item.Top
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 7
                    radius: 3.5
                    color: root.hoofColor
                }
            }

            // Body
            Rectangle {
                x: 28
                y: 54
                width: 120
                height: 104
                radius: 52
                color: root.pigColor

                // Strap visible crossing shoulder
                Rectangle {
                    x: 38
                    y: 16
                    width: 8
                    height: 48
                    radius: 4
                    color: root.strapColor
                    rotation: 15
                }

                // Belly curve
                Rectangle {
                    x: 16
                    y: 18
                    width: 76
                    height: 68
                    radius: 34
                    color: Qt.lighter(root.pigColor, 1.08)
                }
            }

            // Arms
            Rectangle {
                x: 32
                y: 102
                width: 18
                height: 26
                radius: 9
                color: root.pigColor
                rotation: root.waving ? (Math.sin(root.earSwing * 1.5) * 25 - 45) : (-root.legAngle * 0.9)
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

            // Head 3/4 facing left
            Item {
                x: 14
                y: 12
                width: 106
                height: 92

                // Rear Ear
                Item {
                    x: 64
                    y: -4 - root.earSwing
                    width: 24
                    height: 30
                    rotation: 30
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = Qt.darker(root.pigColor, 1.08);
                            ctx.beginPath();
                            ctx.moveTo(16, 28); ctx.lineTo(22, 4); ctx.quadraticCurveTo(10, -2, 2, 18); ctx.closePath(); ctx.fill();
                        }
                    }
                }

                // Front Ear
                Item {
                    x: 10
                    y: -4 + root.earSwing
                    width: 28
                    height: 34
                    rotation: -22
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
                    y: 6
                    width: 92
                    height: 84
                    radius: 42
                    color: root.pigColor
                }

                // Eye
                Item {
                    x: 24
                    y: 36
                    width: 14
                    height: 15
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 14; radius: 6; color: root.eyeColor
                        Rectangle { x: 2; y: 2; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }

                // Blush
                Rectangle { x: 12; y: 46; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.65 }

                // Snout (Forward left)
                Rectangle {
                    x: 0
                    y: 44
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

                // Whistle mouth profile
                Rectangle {
                    x: 18
                    y: 72
                    width: 6
                    height: 6
                    radius: 3
                    color: "#2B1B17"
                }
            }
        }

        // ==============================================================
        // 3. BACK VIEW (Walking away with backpack)
        // ==============================================================
        Item {
            id: backView
            anchors.fill: parent
            visible: root.viewAngle === "back"

            // Left leg stepping
            Rectangle {
                x: 48
                y: 144
                width: 24
                height: 34
                radius: 10
                color: root.pigColor
                rotation: root.legAngle
                transformOrigin: Item.Top
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 16
                    height: 8
                    radius: 4
                    color: root.hoofColor
                }
            }

            // Right leg stepping
            Rectangle {
                x: 98
                y: 144
                width: 24
                height: 34
                radius: 10
                color: root.pigColor
                rotation: -root.legAngle
                transformOrigin: Item.Top
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 16
                    height: 8
                    radius: 4
                    color: root.hoofColor
                }
            }

            // Round Piggy Rear
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 54
                width: 130
                height: 108
                radius: 54
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
                        ctx.moveTo(width / 2, 72);
                        ctx.lineTo(width / 2, 96);
                        ctx.stroke();
                    }
                }

                // Cute wagging tail right under the backpack
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 30
                    width: 32
                    height: 32
                    rotation: root.earSwing * 3

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

            // Backpack prominent on center back!
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 62
                width: 58
                height: 58
                radius: 16
                color: root.backpackColor
                border.color: root.strapColor
                border.width: 2.5

                // Top carry handle
                Rectangle {
                    anchors.bottom: parent.top
                    anchors.bottomMargin: -3
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 20
                    height: 8
                    radius: 4
                    color: "transparent"
                    border.color: root.strapColor
                    border.width: 2.5
                }

                // Backpack zipper flap
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    width: parent.width - 16
                    height: 6
                    radius: 3
                    color: Qt.darker(root.backpackColor, 1.2)
                }

                // Zipper Pocket
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 22
                    width: parent.width - 18
                    height: 26
                    radius: 8
                    color: Qt.darker(root.backpackColor, 1.12)
                }

                // Dual shoulder straps wrapping over shoulders
                Rectangle {
                    anchors.top: parent.top
                    x: -6
                    width: 10
                    height: 24
                    radius: 4
                    color: root.strapColor
                    rotation: -12
                }
                Rectangle {
                    anchors.top: parent.top
                    x: parent.width - 4
                    width: 10
                    height: 24
                    radius: 4
                    color: root.strapColor
                    rotation: 12
                }
            }

            // Head (Back of Head)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: 108
                height: 90

                Item {
                    x: 8; y: -2 + root.earSwing; width: 28; height: 32; rotation: -24
                    Rectangle { anchors.fill: parent; radius: 14; color: root.pigColor }
                }
                Item {
                    x: 72; y: -2 - root.earSwing; width: 28; height: 32; rotation: 24
                    Rectangle { anchors.fill: parent; radius: 14; color: root.pigColor }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 100
                    height: 84
                    radius: 42
                    color: root.pigColor
                }
            }
        }
    }

    // Mouse Area
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggerWave()
    }
}
