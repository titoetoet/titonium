pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"
    property color capColor: "#845EC2"
    property color capAccentColor: "#D65DB1"
    property color pillowColor: "#FFF3E0"

    // Multi-angle perspective: "front" | "left" | "right" | "back"
    property string viewAngle: "front"

    property bool paused: false
    property bool awake: false

    implicitWidth: 260
    implicitHeight: 250

    // Gentle Breathing / Sleep oscillation
    property real breathScale: 1.0
    property real capSway: 0
    property real earDroop: 0

    SequentialAnimation {
        running: !root.paused && !root.awake
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "breathScale"
                from: 1.0
                to: 1.05
                duration: 1600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "capSway"
                from: -4
                to: 5
                duration: 1600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "earDroop"
                from: 0
                to: 3
                duration: 1600
                easing.type: Easing.InOutSine
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "breathScale"
                from: 1.05
                to: 1.0
                duration: 1600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "capSway"
                from: 5
                to: -4
                duration: 1600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "earDroop"
                from: 3
                to: 0
                duration: 1600
                easing.type: Easing.InOutSine
            }
        }
    }

    // Wake-up trigger animation
    function wakeUp() {
        if (root.awake)
            return;
        root.awake = true;
        wakeTimer.restart();
    }

    Timer {
        id: wakeTimer
        interval: 2200
        onTriggered: root.awake = false
    }

    // Floating Zzz particle spawner
    Timer {
        interval: 1100
        running: !root.paused && !root.awake
        repeat: true
        onTriggered: {
            zzzListModel.append({
                initX: root.width / 2 + (root.viewAngle === "left" ? 10 : (root.viewAngle === "right" ? 45 : 35)) + (Math.random() * 12 - 6),
                initY: root.height / 2 - 40,
                fontSize: 14 + Math.floor(Math.random() * 10),
                driftX: (root.viewAngle === "left" ? -25 : 25) + Math.random() * 20
            });
            if (zzzListModel.count > 6) {
                zzzListModel.remove(0);
            }
        }
    }

    ListModel {
        id: zzzListModel
    }

    // Floating Zzz view
    Repeater {
        model: zzzListModel
        delegate: Item {
            id: zzzItem
            required property real initX
            required property real initY
            required property int fontSize
            required property real driftX
            required property int index

            x: initX
            y: initY

            Text {
                text: "Z"
                font.bold: true
                font.pixelSize: zzzItem.fontSize
                font.family: "Sans-Serif"
                color: Qt.tint("#9B51E0", Qt.rgba(1, 1, 1, 0.2))
            }

            NumberAnimation on y {
                from: zzzItem.initY
                to: zzzItem.initY - 70
                duration: 1800
                easing.type: Easing.OutQuad
            }
            NumberAnimation on x {
                from: zzzItem.initX
                to: zzzItem.initX + zzzItem.driftX
                duration: 1800
                easing.type: Easing.InOutSine
            }
            NumberAnimation on opacity {
                from: 1.0
                to: 0.0
                duration: 1800
                easing.type: Easing.InQuad
                onFinished: {
                    if (zzzItem.index >= 0 && zzzItem.index < zzzListModel.count) {
                        zzzListModel.remove(zzzItem.index);
                    }
                }
            }
        }
    }

    // Main Piggy Sleeping Scene
    Item {
        id: pigBody
        anchors.centerIn: parent
        width: 170
        height: 180
        scale: root.breathScale
        transformOrigin: Item.Bottom

        // ==============================================================
        // 1. FRONT VIEW (Chính diện)
        // ==============================================================
        Item {
            id: frontView
            anchors.fill: parent
            visible: root.viewAngle === "front"

            // Tail at side
            Canvas {
                id: frontTail
                x: 12
                y: 112
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

            // Pillow
            Rectangle {
                id: frontPillow
                x: 20
                y: 105
                width: 130
                height: 60
                radius: 26
                color: root.pillowColor
                border.color: "#FFE0B2"
                border.width: 2

                Rectangle {
                    anchors.centerIn: parent
                    width: 90
                    height: 34
                    radius: 17
                    color: "#F9EBEA"
                    opacity: 0.5
                }
            }

            // Body
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: frontPillow.top
                anchors.bottomMargin: -38
                width: 128
                height: 108
                radius: 54
                color: root.pigColor

                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    width: 82
                    height: 68
                    radius: 34
                    color: Qt.lighter(root.pigColor, 1.08)
                }
            }

            // Little Sleeping Hooves hugging the pillow
            Rectangle {
                x: 44
                y: 110
                width: 24
                height: 20
                radius: 10
                color: root.pigColor
                rotation: 12
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 7
                    radius: 3.5
                    color: root.hoofColor
                }
            }
            Rectangle {
                x: 100
                y: 110
                width: 24
                height: 20
                radius: 10
                color: root.pigColor
                rotation: -12
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 14
                    height: 7
                    radius: 3.5
                    color: root.hoofColor
                }
            }

            // Head
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: 110
                height: 96

                // Ears
                Item {
                    x: 6
                    y: -4 + root.earDroop
                    width: 30
                    height: 34
                    rotation: -28
                    transformOrigin: Item.BottomRight
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath();
                            ctx.moveTo(8, 32);
                            ctx.lineTo(2, 6);
                            ctx.quadraticCurveTo(15, -2, 28, 22);
                            ctx.closePath();
                            ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath();
                            ctx.moveTo(10, 26);
                            ctx.lineTo(8, 12);
                            ctx.quadraticCurveTo(15, 8, 22, 22);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }
                Item {
                    x: 74
                    y: -4 + root.earDroop
                    width: 30
                    height: 34
                    rotation: 28
                    transformOrigin: Item.BottomLeft
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath();
                            ctx.moveTo(22, 32);
                            ctx.lineTo(28, 6);
                            ctx.quadraticCurveTo(15, -2, 2, 22);
                            ctx.closePath();
                            ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath();
                            ctx.moveTo(20, 26);
                            ctx.lineTo(22, 12);
                            ctx.quadraticCurveTo(15, 8, 8, 22);
                            ctx.closePath();
                            ctx.fill();
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
                    x: 28
                    y: 38
                    width: 18
                    height: 14
                    Canvas {
                        anchors.fill: parent
                        visible: !root.awake
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = root.eyeColor;
                            ctx.lineWidth = 3.2;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.arc(9, 6, 6, 0.1 * Math.PI, 0.9 * Math.PI, false);
                            ctx.stroke();
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 13
                        height: 15
                        radius: 7
                        color: root.eyeColor
                        visible: root.awake
                        Rectangle { x: 3; y: 3; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }
                Item {
                    x: 64
                    y: 38
                    width: 18
                    height: 14
                    Canvas {
                        anchors.fill: parent
                        visible: !root.awake
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = root.eyeColor;
                            ctx.lineWidth = 3.2;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.arc(9, 6, 6, 0.1 * Math.PI, 0.9 * Math.PI, false);
                            ctx.stroke();
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 13
                        height: 15
                        radius: 7
                        color: root.eyeColor
                        visible: root.awake
                        Rectangle { x: 3; y: 3; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }

                // Blush
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

                // Nightcap
                Item {
                    x: 14
                    y: -36
                    width: 86
                    height: 56
                    rotation: root.capSway
                    transformOrigin: Item.Bottom
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.capColor;
                            ctx.beginPath();
                            ctx.moveTo(10, 48);
                            ctx.bezierCurveTo(20, 20, 45, 6, 80, 28);
                            ctx.bezierCurveTo(60, 36, 40, 52, 28, 52);
                            ctx.closePath();
                            ctx.fill();
                            ctx.strokeStyle = root.capAccentColor;
                            ctx.lineWidth = 3;
                            ctx.beginPath();
                            ctx.moveTo(22, 38);
                            ctx.lineTo(34, 18);
                            ctx.moveTo(38, 42);
                            ctx.lineTo(52, 21);
                            ctx.stroke();
                        }
                    }
                    Rectangle { x: 8; y: 44; width: 46; height: 10; radius: 5; color: "#FFFFFF" }
                    Rectangle { x: 74; y: 24; width: 16; height: 16; radius: 8; color: "#FFFFFF"; border.color: "#E2E8F0"; border.width: 1 }
                }
            }
        }

        // ==============================================================
        // 2. ANGLED 3/4 VIEW (Nghiêng trái / Nghiêng phải)
        // ==============================================================
        Item {
            id: angledView
            anchors.fill: parent
            visible: root.viewAngle === "left" || root.viewAngle === "right"
            transform: Scale {
                xScale: root.viewAngle === "right" ? -1 : 1
                origin.x: angledView.width / 2
            }

            // Tail sticking out rear (right side)
            Canvas {
                id: angledTail
                x: 130
                y: 100
                width: 36
                height: 36
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor;
                    ctx.lineWidth = 4.5;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(18, 18, 12, 0.4 * Math.PI, 1.8 * Math.PI, false);
                    ctx.stroke();
                }
            }

            // Pillow angled
            Rectangle {
                id: angledPillow
                x: 10
                y: 110
                width: 145
                height: 55
                radius: 25
                color: root.pillowColor
                border.color: "#FFE0B2"
                border.width: 2
                rotation: -3
            }

            // Body angled (tilted left)
            Rectangle {
                x: 28
                y: 65
                width: 122
                height: 98
                radius: 49
                color: root.pigColor

                // Belly curve
                Rectangle {
                    x: 18
                    y: 18
                    width: 76
                    height: 64
                    radius: 32
                    color: Qt.lighter(root.pigColor, 1.08)
                }
            }

            // Front hooves cuddling pillow edge
            Rectangle {
                x: 32
                y: 116
                width: 22
                height: 18
                radius: 9
                color: root.pigColor
                rotation: 20
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
                x: 60
                y: 122
                width: 20
                height: 16
                radius: 8
                color: root.pigColor
                rotation: 5
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 10
                    height: 5
                    radius: 2.5
                    color: root.hoofColor
                }
            }

            // Head 3/4 tilted towards left
            Item {
                x: 16
                y: 14
                width: 104
                height: 92

                // Rear Ear
                Item {
                    x: 62
                    y: -6 + root.earDroop
                    width: 26
                    height: 32
                    rotation: 32
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = Qt.darker(root.pigColor, 1.08);
                            ctx.beginPath();
                            ctx.moveTo(18, 30);
                            ctx.lineTo(24, 4);
                            ctx.quadraticCurveTo(12, -2, 2, 20);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }

                // Head ellipse
                Rectangle {
                    x: 10
                    y: 6
                    width: 90
                    height: 82
                    radius: 41
                    color: root.pigColor
                }

                // Front Ear
                Item {
                    x: 10
                    y: -8 + root.earDroop
                    width: 28
                    height: 34
                    rotation: -20
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath();
                            ctx.moveTo(8, 32);
                            ctx.lineTo(2, 6);
                            ctx.quadraticCurveTo(15, -2, 26, 22);
                            ctx.closePath();
                            ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath();
                            ctx.moveTo(10, 26);
                            ctx.lineTo(8, 12);
                            ctx.quadraticCurveTo(15, 8, 20, 22);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }
                }

                // Eye (Main profile eye)
                Item {
                    x: 26
                    y: 36
                    width: 16
                    height: 12
                    Canvas {
                        anchors.fill: parent
                        visible: !root.awake
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = root.eyeColor;
                            ctx.lineWidth = 3.2;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.arc(8, 6, 6, 0.1 * Math.PI, 0.9 * Math.PI, false);
                            ctx.stroke();
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 14
                        radius: 6
                        color: root.eyeColor
                        visible: root.awake
                        Rectangle { x: 2; y: 3; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }

                // Eye (Secondary farther eye peeking)
                Item {
                    x: 58
                    y: 34
                    width: 12
                    height: 10
                    opacity: 0.75
                    Canvas {
                        anchors.fill: parent
                        visible: !root.awake
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = root.eyeColor;
                            ctx.lineWidth = 2.6;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.arc(6, 5, 4.5, 0.1 * Math.PI, 0.9 * Math.PI, false);
                            ctx.stroke();
                        }
                    }
                }

                // Blush
                Rectangle { x: 16; y: 46; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.65 }

                // Snout (Shifted forward left)
                Rectangle {
                    x: 2
                    y: 44
                    width: 36
                    height: 26
                    radius: 13
                    color: root.snoutColor

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 2
                        x: 6
                        width: 16
                        height: 4
                        radius: 2
                        color: "#50FFFFFF"
                    }
                    // Left nostril prominent
                    Rectangle { x: 8; y: 8; width: 5; height: 9; radius: 2.5; color: "#2B1B17" }
                    Rectangle { x: 20; y: 8; width: 4; height: 8; radius: 2; color: "#2B1B17"; opacity: 0.6 }
                }

                // Nightcap (draping back towards right)
                Item {
                    x: 22
                    y: -34
                    width: 80
                    height: 54
                    rotation: root.capSway * 1.2
                    transformOrigin: Item.BottomLeft
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.capColor;
                            ctx.beginPath();
                            ctx.moveTo(8, 46);
                            ctx.bezierCurveTo(18, 16, 45, 4, 76, 26);
                            ctx.bezierCurveTo(55, 34, 38, 48, 24, 48);
                            ctx.closePath();
                            ctx.fill();
                            ctx.strokeStyle = root.capAccentColor;
                            ctx.lineWidth = 3;
                            ctx.beginPath();
                            ctx.moveTo(20, 36);
                            ctx.lineTo(32, 16);
                            ctx.stroke();
                        }
                    }
                    Rectangle { x: 6; y: 42; width: 40; height: 9; radius: 4.5; color: "#FFFFFF" }
                    Rectangle { x: 70; y: 22; width: 15; height: 15; radius: 7.5; color: "#FFFFFF"; border.color: "#E2E8F0"; border.width: 1 }
                }
            }
        }

        // ==============================================================
        // 3. BACK VIEW (Góc lưng - Nhìn từ phía sau)
        // ==============================================================
        Item {
            id: backView
            anchors.fill: parent
            visible: root.viewAngle === "back"

            // Pillow background
            Rectangle {
                x: 18
                y: 110
                width: 134
                height: 58
                radius: 26
                color: root.pillowColor
                border.color: "#FFE0B2"
                border.width: 2
            }

            // Chubby Round Piggy Butt & Back
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 50
                width: 132
                height: 112
                radius: 56
                color: root.pigColor

                // Butt crease line (subtle curve)
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Qt.darker(root.pigColor, 1.1);
                        ctx.lineWidth = 2.5;
                        ctx.beginPath();
                        ctx.moveTo(width / 2, 75);
                        ctx.lineTo(width / 2, 98);
                        ctx.stroke();
                    }
                }

                // Cute Wiggly Spiral Tail right in the center!
                Item {
                    id: wigglyTail
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 32
                    width: 32
                    height: 32
                    rotation: Math.sin(root.capSway * 0.8) * 16

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

            // Head (Back of Head - smooth pink, no face)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 14
                width: 110
                height: 94

                // Left Ear Back
                Item {
                    x: 8
                    y: -2 + root.earDroop
                    width: 28
                    height: 32
                    rotation: -26
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: root.pigColor
                    }
                }

                // Right Ear Back
                Item {
                    x: 74
                    y: -2 + root.earDroop
                    width: 28
                    height: 32
                    rotation: 26
                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: root.pigColor
                    }
                }

                // Back of Head Circle
                Rectangle {
                    anchors.centerIn: parent
                    width: 100
                    height: 86
                    radius: 43
                    color: root.pigColor
                }

                // Nightcap draped down back
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -32
                    width: 82
                    height: 70
                    rotation: root.capSway * 0.7
                    transformOrigin: Item.Bottom

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.capColor;
                            ctx.beginPath();
                            ctx.moveTo(12, 46);
                            ctx.bezierCurveTo(24, 18, 56, 18, 70, 46);
                            ctx.bezierCurveTo(62, 54, 20, 54, 12, 46);
                            ctx.closePath();
                            ctx.fill();

                            // Cap tail draping down
                            ctx.beginPath();
                            ctx.moveTo(42, 48);
                            ctx.quadraticCurveTo(55, 62, 60, 68);
                            ctx.lineWidth = 14;
                            ctx.strokeStyle = root.capColor;
                            ctx.lineCap = "round";
                            ctx.stroke();
                        }
                    }

                    // White Brim Band
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 40
                        width: 54
                        height: 10
                        radius: 5
                        color: "#FFFFFF"
                    }

                    // Pom-pom dangling at tip
                    Rectangle {
                        x: 54
                        y: 58
                        width: 16
                        height: 16
                        radius: 8
                        color: "#FFFFFF"
                        border.color: "#E2E8F0"
                        border.width: 1
                    }
                }
            }

            // Feet resting on pillow
            Rectangle {
                x: 32
                y: 134
                width: 18
                height: 14
                radius: 7
                color: root.hoofColor
            }
            Rectangle {
                x: 120
                y: 134
                width: 18
                height: 14
                radius: 7
                color: root.hoofColor
            }
        }
    }

    // Interactive mouse area
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.wakeUp()
    }
}
