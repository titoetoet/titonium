pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"

    property color cupColor: "#F6E05E"
    property color teaColor: "#D69E2E"
    property color bobaColor: "#2D3748"

    // Multi-angle perspective: "front" | "left" | "right" | "back"
    property string viewAngle: "front"

    property bool paused: false
    property bool sipping: false

    implicitWidth: 260
    implicitHeight: 250

    property real swayAngle: 0
    property real cheekPuff: 1.0

    SequentialAnimation {
        running: !root.paused
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "swayAngle"
            from: -3.5
            to: 3.5
            duration: 1800
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "swayAngle"
            from: 3.5
            to: -3.5
            duration: 1800
            easing.type: Easing.InOutSine
        }
    }

    function takeSip() {
        if (root.sipping)
            return;
        root.sipping = true;
        sipAnim.restart();
    }

    SequentialAnimation {
        id: sipAnim
        NumberAnimation {
            target: root
            property: "cheekPuff"
            to: 1.22
            duration: 350
            easing.type: Easing.OutBack
        }
        ScriptAction {
            script: {
                for (let i = 0; i < 4; i++) {
                    steamModel.append({
                        symbol: "♥",
                        initX: root.width / 2 + (Math.random() * 20 - 10),
                        initY: root.height / 2 + 10,
                        driftX: (Math.random() * 30 - 15),
                        col: "#FF6584"
                    });
                }
            }
        }
        PauseAnimation { duration: 600 }
        NumberAnimation {
            target: root
            property: "cheekPuff"
            to: 1.0
            duration: 400
            easing.type: Easing.OutBounce
        }
        ScriptAction { script: root.sipping = false }
    }

    Timer {
        interval: 1300
        running: !root.paused
        repeat: true
        onTriggered: {
            steamModel.append({
                symbol: Math.random() > 0.4 ? "♥" : "~",
                initX: root.width / 2 + (root.viewAngle === "left" ? -15 : (root.viewAngle === "right" ? 15 : 0)) + (Math.random() * 16 - 8),
                initY: root.height / 2 + 10,
                driftX: (Math.random() * 26 - 13),
                col: "#F687B3"
            });
            if (steamModel.count > 7) {
                steamModel.remove(0);
            }
        }
    }

    ListModel {
        id: steamModel
    }

    Repeater {
        model: steamModel
        delegate: Item {
            id: steamItem
            required property string symbol
            required property real initX
            required property real initY
            required property real driftX
            required property color col
            required property int index

            x: initX
            y: initY

            Text {
                text: steamItem.symbol
                font.bold: true
                font.pixelSize: 14
                color: steamItem.col
            }

            NumberAnimation on y {
                from: steamItem.initY
                to: steamItem.initY - 60
                duration: 1600
                easing.type: Easing.OutCubic
            }
            NumberAnimation on x {
                from: steamItem.initX
                to: steamItem.initX + steamItem.driftX
                duration: 1600
                easing.type: Easing.InOutSine
            }
            NumberAnimation on opacity {
                from: 0.9
                to: 0.0
                duration: 1600
                easing.type: Easing.InQuad
                onFinished: {
                    if (steamItem.index >= 0 && steamItem.index < steamModel.count) {
                        steamModel.remove(steamItem.index);
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
        rotation: root.swayAngle
        transformOrigin: Item.Bottom

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
                scale: root.cheekPuff
                transformOrigin: Item.Center

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

                Rectangle { x: 16; y: 46; width: 16; height: 10; radius: 5; color: root.blushColor; opacity: 0.7 }
                Rectangle { x: 80; y: 46; width: 16; height: 10; radius: 5; color: root.blushColor; opacity: 0.7 }

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

            // Boba Cup & Hooves
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                width: 70
                height: 70

                // Red Straw
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 4
                    y: -14
                    width: 6
                    height: 36
                    radius: 3
                    color: "#E53E3E"
                    rotation: 8
                }

                // Cup
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 12
                    width: 46
                    height: 52
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.4)
                    border.color: "#CBD5E0"
                    border.width: 1.5

                    // Tea inside
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: parent.width - 4
                        height: 42
                        radius: 6
                        color: root.teaColor

                        // Boba pearls
                        Rectangle { x: 6; y: 28; width: 8; height: 8; radius: 4; color: root.bobaColor }
                        Rectangle { x: 18; y: 30; width: 8; height: 8; radius: 4; color: root.bobaColor }
                        Rectangle { x: 28; y: 28; width: 8; height: 8; radius: 4; color: root.bobaColor }
                        Rectangle { x: 12; y: 20; width: 8; height: 8; radius: 4; color: root.bobaColor }
                        Rectangle { x: 24; y: 20; width: 8; height: 8; radius: 4; color: root.bobaColor }
                    }

                    // Cup lid
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: parent.width + 6
                        height: 6
                        radius: 3
                        color: root.cupColor
                    }
                }

                // Left hugging hoof
                Rectangle {
                    x: 6; y: 24; width: 18; height: 16; radius: 8; color: root.pigColor; rotation: 18
                    Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 10; radius: 3; color: root.hoofColor }
                }
                // Right hugging hoof
                Rectangle {
                    x: 46; y: 24; width: 18; height: 16; radius: 8; color: root.pigColor; rotation: -18
                    Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 10; radius: 3; color: root.hoofColor }
                }
            }
        }

        // ==============================================================
        // 2. ANGLED 3/4 BOBA VIEW (Nghiêng trái / Nghiêng phải)
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
                scale: root.cheekPuff

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

                Rectangle { x: 12; y: 46; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.7 }

                // Snout
                Rectangle {
                    x: 0; y: 44; width: 36; height: 26; radius: 13; color: root.snoutColor
                    Rectangle { x: 7; y: 8; width: 5; height: 9; radius: 2.5; color: "#2B1B17" }
                    Rectangle { x: 19; y: 8; width: 4; height: 8; radius: 2; color: "#2B1B17"; opacity: 0.5 }
                }
            }

            // Angled Boba Cup
            Item {
                x: 18; y: 100; width: 60; height: 68

                Rectangle {
                    x: 14; y: -8; width: 6; height: 32; radius: 3; color: "#E53E3E"; rotation: 12
                }

                Rectangle {
                    x: 8; y: 12; width: 42; height: 48; radius: 8; color: Qt.rgba(1, 1, 1, 0.4)
                    border.color: "#CBD5E0"; border.width: 1.5

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                        width: parent.width - 4; height: 38; radius: 6; color: root.teaColor
                        Rectangle { x: 4; y: 24; width: 7; height: 7; radius: 3.5; color: root.bobaColor }
                        Rectangle { x: 14; y: 26; width: 7; height: 7; radius: 3.5; color: root.bobaColor }
                        Rectangle { x: 24; y: 24; width: 7; height: 7; radius: 3.5; color: root.bobaColor }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top
                        width: parent.width + 4; height: 5; radius: 2.5; color: root.cupColor
                    }
                }

                Rectangle {
                    x: 2; y: 26; width: 18; height: 16; radius: 8; color: root.pigColor; rotation: 12
                    Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 9; radius: 2.5; color: root.hoofColor }
                }
            }
        }

        // ==============================================================
        // 3. BACK VIEW (Boba pig from behind)
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
                    rotation: root.swayAngle * 4

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
                scale: root.cheekPuff

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

                // Straw sticking up above head
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 16
                    width: 6
                    height: 20
                    radius: 3
                    color: "#E53E3E"
                }
            }

            // Arms hugging cup in front (visible elbows)
            Rectangle {
                x: 18; y: 92; width: 20; height: 26; radius: 10; color: root.pigColor; rotation: 25
            }
            Rectangle {
                x: 132; y: 92; width: 20; height: 26; radius: 10; color: root.pigColor; rotation: -25
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.takeSip()
    }
}
