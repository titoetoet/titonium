pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"

    property color weightColor: "#2D3748"
    property color barColor: "#CBD5E0"
    property color wristbandColor: "#ED8936"

    // Multi-angle perspective: "front" | "left" | "right" | "back"
    property string viewAngle: "front"

    property bool paused: false
    property bool flexMode: false

    implicitWidth: 260
    implicitHeight: 250

    property real barY: 0
    property real armAngle: 0
    property int repCount: 0
    property bool isLifting: false

    SequentialAnimation {
        id: liftAnim
        running: !root.paused && !root.flexMode
        loops: Animation.Infinite

        ScriptAction { script: root.isLifting = true }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "barY"
                from: 20
                to: -28
                duration: 900
                easing.type: Easing.OutBack
            }
            NumberAnimation {
                target: root
                property: "armAngle"
                from: 10
                to: -40
                duration: 900
                easing.type: Easing.OutBack
            }
        }

        ScriptAction {
            script: {
                root.repCount++;
                root.spawnFlexSpark();
            }
        }
        PauseAnimation { duration: 400 }

        ScriptAction { script: root.isLifting = false }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "barY"
                from: -28
                to: 20
                duration: 700
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: root
                property: "armAngle"
                from: -40
                to: 10
                duration: 700
                easing.type: Easing.InOutQuad
            }
        }
        PauseAnimation { duration: 500 }
    }

    function triggerFlex() {
        if (root.flexMode)
            return;
        root.flexMode = true;
        flexTimer.restart();
    }

    Timer {
        id: flexTimer
        interval: 3000
        onTriggered: root.flexMode = false
    }

    function spawnFlexSpark() {
        sparkModel.append({
            symbol: root.repCount % 2 === 0 ? "💪" : "🔥",
            initX: root.width / 2 + (Math.random() * 40 - 20),
            initY: root.height / 2 - 40,
            driftX: (Math.random() * 30 - 15),
            col: "#F6AD55"
        });
        if (sparkModel.count > 8) {
            sparkModel.remove(0);
        }
    }

    ListModel {
        id: sparkModel
    }

    Repeater {
        model: sparkModel
        delegate: Item {
            id: sparkItem
            required property string symbol
            required property real initX
            required property real initY
            required property real driftX
            required property color col
            required property int index

            x: initX
            y: initY

            Text {
                text: sparkItem.symbol
                font.bold: true
                font.pixelSize: sparkItem.symbol === "💪" ? 17 : 15
                color: sparkItem.col
            }

            NumberAnimation on y {
                from: sparkItem.initY
                to: sparkItem.initY - 55
                duration: 1200
                easing.type: Easing.OutQuad
            }
            NumberAnimation on x {
                from: sparkItem.initX
                to: sparkItem.initX + sparkItem.driftX
                duration: 1200
                easing.type: Easing.InOutSine
            }
            NumberAnimation on opacity {
                from: 1.0
                to: 0.0
                duration: 1200
                easing.type: Easing.InQuad
                onFinished: {
                    if (sparkItem.index >= 0 && sparkItem.index < sparkModel.count) {
                        sparkModel.remove(sparkItem.index);
                    }
                }
            }
        }
    }

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
                y: 10
                width: 112
                height: 98

                Item {
                    x: 6; y: -4; width: 28; height: 34; rotation: -25; transformOrigin: Item.BottomRight
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath(); ctx.moveTo(8, 32); ctx.lineTo(2, 6); ctx.quadraticCurveTo(15, -2, 26, 22); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath(); ctx.moveTo(10, 26); ctx.lineTo(8, 12); ctx.quadraticCurveTo(15, 8, 20, 22); ctx.closePath(); ctx.fill();
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
                            ctx.beginPath(); ctx.moveTo(20, 32); ctx.lineTo(26, 6); ctx.quadraticCurveTo(15, -2, 2, 22); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath(); ctx.moveTo(18, 26); ctx.lineTo(20, 12); ctx.quadraticCurveTo(15, 8, 8, 22); ctx.closePath(); ctx.fill();
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
                    x: 66; y: 38; width: 18; height: 16
                    Rectangle {
                        anchors.centerIn: parent
                        width: 13; height: 15; radius: 7; color: root.eyeColor
                        Rectangle { x: 3; y: 2; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }

                // Sweat drop
                Text {
                    x: 88; y: 24
                    text: "💦"
                    font.pixelSize: 13
                    visible: root.isLifting
                }

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
                        anchors.top: parent.top; anchors.topMargin: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 20; height: 5; radius: 2.5; color: "#50FFFFFF"
                    }
                    Rectangle { x: 11; y: 9; width: 6; height: 11; radius: 3; color: "#2B1B17" }
                    Rectangle { x: 27; y: 9; width: 6; height: 11; radius: 3; color: "#2B1B17" }
                }
            }

            // Barbell & Arms
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 50 + root.barY
                width: 160
                height: 50

                // Steel Bar
                Rectangle {
                    anchors.centerIn: parent
                    width: 150
                    height: 6
                    radius: 3
                    color: root.barColor
                }

                // Left Weights
                Rectangle {
                    x: 4; y: 5; width: 12; height: 40; radius: 4; color: root.weightColor
                }
                Rectangle {
                    x: 18; y: 10; width: 8; height: 30; radius: 3; color: Qt.lighter(root.weightColor, 1.2)
                }

                // Right Weights
                Rectangle {
                    x: 144; y: 5; width: 12; height: 40; radius: 4; color: root.weightColor
                }
                Rectangle {
                    x: 134; y: 10; width: 8; height: 30; radius: 3; color: Qt.lighter(root.weightColor, 1.2)
                }

                // Left Arm & Wristband
                Rectangle {
                    x: 36; y: 18; width: 14; height: 26; radius: 7; color: root.pigColor
                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width; height: 8; radius: 3; color: root.wristbandColor
                    }
                }

                // Right Arm & Wristband
                Rectangle {
                    x: 110; y: 18; width: 14; height: 26; radius: 7; color: root.pigColor
                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width; height: 8; radius: 3; color: root.wristbandColor
                    }
                }
            }
        }

        // ==============================================================
        // 2. ANGLED 3/4 GYM VIEW (Nghiêng trái / Nghiêng phải)
        // ==============================================================
        Item {
            id: angledView
            anchors.fill: parent
            visible: root.viewAngle === "left" || root.viewAngle === "right"
            transform: Scale {
                xScale: root.viewAngle === "right" ? -1 : 1
                origin.x: angledView.width / 2
            }

            // Tail
            Canvas {
                x: 130; y: 115; width: 32; height: 32
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor; ctx.lineWidth = 4; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.arc(16, 16, 10, 0.4 * Math.PI, 1.8 * Math.PI, false); ctx.stroke();
                }
            }

            // Body
            Rectangle {
                x: 30; y: 60; width: 120; height: 108; radius: 54; color: root.pigColor
                Rectangle { x: 16; y: 18; width: 76; height: 68; radius: 34; color: Qt.lighter(root.pigColor, 1.08) }
            }

            // Head 3/4
            Item {
                x: 16; y: 12; width: 108; height: 94

                Item {
                    x: 64; y: -4; width: 26; height: 30; rotation: 28
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = Qt.darker(root.pigColor, 1.08);
                            ctx.beginPath(); ctx.moveTo(16, 28); ctx.lineTo(22, 4); ctx.quadraticCurveTo(10, -2, 2, 18); ctx.closePath(); ctx.fill();
                        }
                    }
                }
                Item {
                    x: 12; y: -4; width: 28; height: 34; rotation: -22
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath(); ctx.moveTo(8, 32); ctx.lineTo(2, 6); ctx.quadraticCurveTo(15, -2, 26, 22); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath(); ctx.moveTo(10, 26); ctx.lineTo(8, 12); ctx.quadraticCurveTo(15, 8, 20, 22); ctx.closePath(); ctx.fill();
                        }
                    }
                }

                Rectangle { x: 10; y: 6; width: 92; height: 84; radius: 42; color: root.pigColor }

                Item {
                    x: 24; y: 34; width: 14; height: 15
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 14; radius: 6; color: root.eyeColor
                        Rectangle { x: 2; y: 2; width: 4; height: 4; radius: 2; color: "#FFFFFF" }
                    }
                }

                Rectangle { x: 12; y: 46; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.75 }

                // Snout
                Rectangle {
                    x: 0; y: 44; width: 36; height: 26; radius: 13; color: root.snoutColor
                    Rectangle { x: 7; y: 8; width: 5; height: 9; radius: 2.5; color: "#2B1B17" }
                    Rectangle { x: 19; y: 8; width: 4; height: 8; radius: 2; color: "#2B1B17"; opacity: 0.5 }
                }
            }

            // Angled Barbell
            Item {
                x: 10
                y: 48 + root.barY
                width: 145
                height: 52

                // Steel bar angled
                Rectangle {
                    x: 0; y: 22; width: 140; height: 6; radius: 3; color: root.barColor
                    rotation: -6
                }

                // Front Weight plate
                Rectangle {
                    x: 4; y: 6; width: 14; height: 42; radius: 5; color: root.weightColor
                }
                // Rear Weight plate
                Rectangle {
                    x: 126; y: 0; width: 12; height: 38; radius: 4; color: Qt.darker(root.weightColor, 1.1)
                }

                // Arm holding bar
                Rectangle {
                    x: 36; y: 16; width: 16; height: 26; radius: 8; color: root.pigColor
                    Rectangle {
                        anchors.top: parent.top; width: parent.width; height: 8; radius: 3; color: root.wristbandColor
                    }
                }
            }
        }

        // ==============================================================
        // 3. BACK VIEW (Lifting seen from behind)
        // ==============================================================
        Item {
            id: backView
            anchors.fill: parent
            visible: root.viewAngle === "back"

            // Round Piggy Rear
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 52
                width: 130
                height: 110
                radius: 55
                color: root.pigColor

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Qt.darker(root.pigColor, 1.1);
                        ctx.lineWidth = 2.5;
                        ctx.beginPath();
                        ctx.moveTo(width / 2, 70); ctx.lineTo(width / 2, 96); ctx.stroke();
                    }
                }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 30
                    width: 32; height: 32
                    rotation: Math.sin(root.barY * 0.1) * 20

                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = root.pigColor; ctx.lineWidth = 4.5; ctx.lineCap = "round";
                            ctx.beginPath(); ctx.arc(16, 16, 9, 0.2 * Math.PI, 1.8 * Math.PI, false); ctx.stroke();
                        }
                    }
                }
            }

            // Head (Back of Head)
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: 112
                height: 94

                Item {
                    x: 8; y: -4; width: 26; height: 32; rotation: -24
                    Rectangle { anchors.fill: parent; radius: 13; color: root.pigColor }
                }
                Item {
                    x: 78; y: -4; width: 26; height: 32; rotation: 24
                    Rectangle { anchors.fill: parent; radius: 13; color: root.pigColor }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 100
                    height: 84
                    radius: 42
                    color: root.pigColor
                }
            }

            // Barbell Overhead seen from behind
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 48 + root.barY
                width: 160
                height: 50

                Rectangle {
                    anchors.centerIn: parent
                    width: 150
                    height: 6
                    radius: 3
                    color: root.barColor
                }

                Rectangle { x: 4; y: 5; width: 12; height: 40; radius: 4; color: root.weightColor }
                Rectangle { x: 144; y: 5; width: 12; height: 40; radius: 4; color: root.weightColor }

                // Arms lifting from back
                Rectangle {
                    x: 36; y: 16; width: 14; height: 26; radius: 7; color: root.pigColor
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 8; radius: 3; color: root.wristbandColor }
                }
                Rectangle {
                    x: 110; y: 16; width: 14; height: 26; radius: 7; color: root.pigColor
                    Rectangle { anchors.top: parent.top; width: parent.width; height: 8; radius: 3; color: root.wristbandColor }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggerFlex()
    }
}
