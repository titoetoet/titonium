pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"

    property color headphoneColor: "#7928CA"
    property color glowColor: "#00F0FF"
    property color laptopColor: "#2D3748"
    property color screenColor: "#1A202C"

    // Multi-angle perspective: "front" | "left" | "right" | "back"
    property string viewAngle: "front"

    property bool paused: false
    property bool turboMode: false

    implicitWidth: 260
    implicitHeight: 250

    readonly property int typingInterval: root.turboMode ? 70 : 150
    property int typingFrame: 0
    property real headBop: 0

    Timer {
        interval: root.typingInterval
        running: !root.paused
        repeat: true
        onTriggered: {
            root.typingFrame = (root.typingFrame + 1) % 4;
            root.headBop = (root.typingFrame % 2 === 0) ? 3 : 0;

            if (Math.random() > (root.turboMode ? 0.2 : 0.6)) {
                root.spawnCodeSnippet();
            }
        }
    }

    function toggleTurbo() {
        root.turboMode = true;
        turboTimer.restart();
    }

    Timer {
        id: turboTimer
        interval: 3500
        onTriggered: root.turboMode = false
    }

    function spawnCodeSnippet() {
        const snippets = ["{ }", "</>", "101", "const", "git", "=>", "0xFA", "npm", "fn()"];
        const chosen = snippets[Math.floor(Math.random() * snippets.length)];
        let initX = root.width / 2 - 20 + (Math.random() * 40);
        let dX = (Math.random() * 40 - 20);
        if (root.viewAngle === "left") {
            initX = root.width / 2 - 40;
            dX = -(15 + Math.random() * 25);
        } else if (root.viewAngle === "right") {
            initX = root.width / 2 + 40;
            dX = 15 + Math.random() * 25;
        }

        codeModel.append({
            symbol: chosen,
            initX: initX,
            initY: root.height / 2 + 30,
            driftX: dX,
            col: (Math.random() > 0.5 ? "#00F0FF" : "#B794F4")
        });
        if (codeModel.count > 10) {
            codeModel.remove(0);
        }
    }

    ListModel {
        id: codeModel
    }

    // Floating Code Particles
    Repeater {
        model: codeModel
        delegate: Item {
            id: codeItem
            required property string symbol
            required property real initX
            required property real initY
            required property real driftX
            required property color col
            required property int index

            x: initX
            y: initY

            Text {
                text: codeItem.symbol
                font.bold: true
                font.pixelSize: 13
                font.family: "Monospace"
                color: codeItem.col
            }

            NumberAnimation on y {
                from: codeItem.initY
                to: codeItem.initY - 65
                duration: 1200
                easing.type: Easing.OutQuad
            }
            NumberAnimation on x {
                from: codeItem.initX
                to: codeItem.initX + codeItem.driftX
                duration: 1200
                easing.type: Easing.InOutSine
            }
            NumberAnimation on opacity {
                from: 0.95
                to: 0.0
                duration: 1200
                easing.type: Easing.InQuad
                onFinished: {
                    if (codeItem.index >= 0 && codeItem.index < codeModel.count) {
                        codeModel.remove(codeItem.index);
                    }
                }
            }
        }
    }

    // Main Pig Container
    Item {
        id: pigRoot
        anchors.centerIn: parent
        width: 170
        height: 190

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

            // Body
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
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

            // Head
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10 + root.headBop
                width: 112
                height: 98
                Behavior on y { NumberAnimation { duration: 60 } }

                // Headphone arch
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -14
                    width: 100
                    height: 50
                    radius: 30
                    color: "transparent"
                    border.color: root.headphoneColor
                    border.width: 5
                }

                // Ears
                Item {
                    x: 6; y: -4; width: 28; height: 34; rotation: -25; transformOrigin: Item.BottomRight
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
                    x: 78; y: -4; width: 28; height: 34; rotation: 25; transformOrigin: Item.BottomLeft
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

                // Head circle
                Rectangle {
                    anchors.centerIn: parent
                    width: 102
                    height: 88
                    radius: 44
                    color: root.pigColor
                }

                // Earcups
                Rectangle {
                    x: 0; y: 22; width: 14; height: 28; radius: 6; color: root.headphoneColor
                    border.color: root.glowColor; border.width: 2
                }
                Rectangle {
                    x: 98; y: 22; width: 14; height: 28; radius: 6; color: root.headphoneColor
                    border.color: root.glowColor; border.width: 2
                }

                // Glasses Bridge
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 42
                    width: 26
                    height: 3
                    color: "#1E293B"
                }

                // Left Glasses & Eye
                Rectangle {
                    x: 24; y: 32; width: 26; height: 24; radius: 12
                    color: Qt.rgba(0, 0.94, 1, 0.15); border.color: "#1E293B"; border.width: 2.5
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10; height: 12; radius: 5; color: root.eyeColor
                        Rectangle { x: 2; y: 2; width: 3; height: 3; radius: 1.5; color: "#FFFFFF" }
                    }
                }

                // Right Glasses & Eye
                Rectangle {
                    x: 62; y: 32; width: 26; height: 24; radius: 12
                    color: Qt.rgba(0, 0.94, 1, 0.15); border.color: "#1E293B"; border.width: 2.5
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10; height: 12; radius: 5; color: root.eyeColor
                        Rectangle { x: 2; y: 2; width: 3; height: 3; radius: 1.5; color: "#FFFFFF" }
                    }
                }

                // Blush
                Rectangle { x: 14; y: 50; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.65 }
                Rectangle { x: 84; y: 50; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.65 }

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
            }

            // Laptop & Keyboard
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 106
                height: 60

                // Screen
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: keyboardBase.top
                    anchors.bottomMargin: -2
                    width: 82
                    height: 48
                    radius: 5
                    color: root.laptopColor
                    border.color: "#4A5568"
                    border.width: 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        height: parent.height - 8
                        radius: 3
                        color: root.screenColor

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Rectangle { width: 44; height: 3; radius: 1.5; color: root.glowColor }
                            Rectangle { width: 56; height: 3; radius: 1.5; color: "#7928CA" }
                            Rectangle { width: 36; height: 3; radius: 1.5; color: "#48BB78" }
                            Rectangle { width: 48; height: 3; radius: 1.5; color: "#ECC94B" }
                        }
                    }
                }

                // Keyboard Base
                Rectangle {
                    id: keyboardBase
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: 100
                    height: 14
                    radius: 3
                    color: root.screenColor
                    border.color: "#4A5568"
                    border.width: 1.5
                }

                // Left Hoof typing
                Rectangle {
                    x: 24
                    y: 38 + (root.typingFrame % 2 === 0 ? -4 : 2)
                    width: 18
                    height: 14
                    radius: 7
                    color: root.pigColor
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                        width: 12; height: 5; radius: 2.5; color: root.hoofColor
                    }
                }

                // Right Hoof typing
                Rectangle {
                    x: 64
                    y: 38 + (root.typingFrame % 2 === 1 ? -4 : 2)
                    width: 18
                    height: 14
                    radius: 7
                    color: root.pigColor
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                        width: 12; height: 5; radius: 2.5; color: root.hoofColor
                    }
                }
            }
        }

        // ==============================================================
        // 2. ANGLED 3/4 CODER VIEW (Nghiêng trái / Nghiêng phải)
        // ==============================================================
        Item {
            id: angledView
            anchors.fill: parent
            visible: root.viewAngle === "left" || root.viewAngle === "right"
            transform: Scale {
                xScale: root.viewAngle === "right" ? -1 : 1
                origin.x: angledView.width / 2
            }

            // Tail at rear right
            Canvas {
                x: 130
                y: 115
                width: 32
                height: 32
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor;
                    ctx.lineWidth = 4;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(16, 16, 10, 0.4 * Math.PI, 1.8 * Math.PI, false);
                    ctx.stroke();
                }
            }

            // Body
            Rectangle {
                x: 30
                y: 60
                width: 120
                height: 108
                radius: 54
                color: root.pigColor
                Rectangle {
                    x: 16; y: 18; width: 76; height: 68; radius: 34
                    color: Qt.lighter(root.pigColor, 1.08)
                }
            }

            // Head 3/4 facing left
            Item {
                x: 16
                y: 12 + root.headBop
                width: 108
                height: 94
                Behavior on y { NumberAnimation { duration: 60 } }

                // Headphone arch angled
                Rectangle {
                    x: 20
                    y: -12
                    width: 78
                    height: 44
                    radius: 22
                    color: "transparent"
                    border.color: root.headphoneColor
                    border.width: 5
                    rotation: -10
                }

                // Rear Ear
                Item {
                    x: 64; y: -4; width: 26; height: 30; rotation: 28
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

                // Head circle
                Rectangle {
                    x: 10
                    y: 6
                    width: 92
                    height: 84
                    radius: 42
                    color: root.pigColor
                }

                // Front Ear
                Item {
                    x: 12; y: -4; width: 28; height: 34; rotation: -22
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

                // Front Earcup
                Rectangle {
                    x: 8; y: 26; width: 14; height: 26; radius: 6; color: root.headphoneColor
                    border.color: root.glowColor; border.width: 2
                }

                // Profile Glasses & Eye
                Rectangle {
                    x: 24; y: 32; width: 24; height: 22; radius: 11
                    color: Qt.rgba(0, 0.94, 1, 0.15); border.color: "#1E293B"; border.width: 2.5
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10; height: 12; radius: 5; color: root.eyeColor
                        Rectangle { x: 2; y: 2; width: 3; height: 3; radius: 1.5; color: "#FFFFFF" }
                    }
                }

                // Blush
                Rectangle { x: 14; y: 48; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.65 }

                // Snout (Shifted left)
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
            }

            // Angled Laptop on the left
            Item {
                x: 8
                y: 110
                width: 76
                height: 60

                // Screen angled
                Rectangle {
                    x: 0
                    y: 6
                    width: 50
                    height: 42
                    radius: 4
                    color: root.laptopColor
                    border.color: "#4A5568"
                    border.width: 1.5
                    rotation: 8

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 6
                        height: parent.height - 6
                        radius: 2
                        color: root.screenColor
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Rectangle { width: 28; height: 2.5; radius: 1; color: root.glowColor }
                            Rectangle { width: 36; height: 2.5; radius: 1; color: "#7928CA" }
                            Rectangle { width: 24; height: 2.5; radius: 1; color: "#48BB78" }
                        }
                    }
                }

                // Keyboard base angled
                Rectangle {
                    x: 10
                    y: 44
                    width: 58
                    height: 12
                    radius: 3
                    color: root.screenColor
                    border.color: "#4A5568"
                    border.width: 1
                }

                // Fast typing hooves
                Rectangle {
                    x: 32
                    y: 36 + (root.typingFrame % 2 === 0 ? -3 : 2)
                    width: 16
                    height: 12
                    radius: 6
                    color: root.pigColor
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                        width: 10; height: 4; radius: 2; color: root.hoofColor
                    }
                }
                Rectangle {
                    x: 48
                    y: 38 + (root.typingFrame % 2 === 1 ? -3 : 2)
                    width: 16
                    height: 12
                    radius: 6
                    color: root.pigColor
                    Rectangle {
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                        width: 10; height: 4; radius: 2; color: root.hoofColor
                    }
                }
            }
        }

        // ==============================================================
        // 3. BACK VIEW (Coder seen from behind)
        // ==============================================================
        Item {
            id: backView
            anchors.fill: parent
            visible: root.viewAngle === "back"

            // Ambient screen glow on floor/sides
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 70
                width: 150
                height: 100
                radius: 50
                color: root.glowColor
                opacity: 0.12
            }

            // Round Piggy Rear
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
                        ctx.lineTo(width / 2, 96);
                        ctx.stroke();
                    }
                }

                // Wagging tail in center
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 30
                    width: 32
                    height: 32
                    rotation: Math.sin(root.typingFrame * 1.6) * 20

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
                y: 10 + root.headBop
                width: 112
                height: 94
                Behavior on y { NumberAnimation { duration: 60 } }

                // Headphone band across back of head
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 14
                    width: 104
                    height: 14
                    radius: 7
                    color: root.headphoneColor
                    border.color: root.glowColor
                    border.width: 1.5
                }

                // Earcups from back
                Rectangle {
                    x: 2; y: 16; width: 14; height: 26; radius: 5; color: root.headphoneColor
                    border.color: root.glowColor; border.width: 1.5
                }
                Rectangle {
                    x: 96; y: 16; width: 14; height: 26; radius: 5; color: root.headphoneColor
                    border.color: root.glowColor; border.width: 1.5
                }

                // Ears back
                Item {
                    x: 8; y: -4; width: 26; height: 32; rotation: -24
                    Rectangle { anchors.fill: parent; radius: 13; color: root.pigColor }
                }
                Item {
                    x: 78; y: -4; width: 26; height: 32; rotation: 24
                    Rectangle { anchors.fill: parent; radius: 13; color: root.pigColor }
                }

                // Head circle
                Rectangle {
                    anchors.centerIn: parent
                    width: 100
                    height: 84
                    radius: 42
                    color: root.pigColor
                }
            }

            // Visible top of screen glowing in front
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 44
                width: 60
                height: 6
                radius: 3
                color: root.laptopColor
                border.color: root.glowColor
                border.width: 1
            }
        }
    }

    // Mouse Area
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleTurbo()
    }
}
