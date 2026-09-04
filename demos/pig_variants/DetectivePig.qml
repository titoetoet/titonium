pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"

    property color hatColor: "#795548"
    property color hatBrimColor: "#5D4037"
    property color glassRimColor: "#D69E2E"

    // Multi-angle perspective: "front" | "left" | "right" | "back"
    property string viewAngle: "front"

    property bool paused: false
    property bool eureka: false

    implicitWidth: 260
    implicitHeight: 250

    property real glassX: 20
    property real glassAngle: -10
    property real snoutTwitch: 0

    SequentialAnimation {
        running: !root.paused
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "glassX"
                from: 10
                to: 60
                duration: 2200
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "glassAngle"
                from: -14
                to: 14
                duration: 2200
                easing.type: Easing.InOutSine
            }
            SequentialAnimation {
                NumberAnimation { target: root; property: "snoutTwitch"; to: 3; duration: 300 }
                NumberAnimation { target: root; property: "snoutTwitch"; to: -3; duration: 300 }
                NumberAnimation { target: root; property: "snoutTwitch"; to: 2; duration: 300 }
                NumberAnimation { target: root; property: "snoutTwitch"; to: 0; duration: 300 }
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "glassX"
                from: 60
                to: 10
                duration: 2200
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "glassAngle"
                from: 14
                to: -14
                duration: 2200
                easing.type: Easing.InOutSine
            }
            SequentialAnimation {
                NumberAnimation { target: root; property: "snoutTwitch"; to: -3; duration: 300 }
                NumberAnimation { target: root; property: "snoutTwitch"; to: 3; duration: 300 }
                NumberAnimation { target: root; property: "snoutTwitch"; to: -2; duration: 300 }
                NumberAnimation { target: root; property: "snoutTwitch"; to: 0; duration: 300 }
            }
        }
    }

    function triggerEureka() {
        if (root.eureka)
            return;
        root.eureka = true;
        eurekaTimer.restart();
    }

    Timer {
        id: eurekaTimer
        interval: 2500
        onTriggered: root.eureka = false
    }

    Item {
        id: pigRoot
        anchors.centerIn: parent
        width: 170
        height: 190

        // Eureka Lightbulb
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -28
            width: 32
            height: 32
            visible: root.eureka
            scale: root.eureka ? 1.0 : 0.0
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            Text {
                anchors.centerIn: parent
                text: "💡"
                font.pixelSize: 26
            }
        }

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

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#A1887F";
                        ctx.beginPath();
                        ctx.moveTo(35, 45); ctx.lineTo(63, 75); ctx.lineTo(40, 110); ctx.lineTo(20, 100); ctx.closePath(); ctx.fill();
                        ctx.beginPath();
                        ctx.moveTo(91, 45); ctx.lineTo(63, 75); ctx.lineTo(86, 110); ctx.lineTo(106, 100); ctx.closePath(); ctx.fill();
                    }
                }
            }

            // Head
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: 112
                height: 98

                // Detective Hat
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -22
                    width: 100
                    height: 44
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        width: 58
                        height: 28
                        radius: 8
                        color: root.hatColor
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 24
                        width: 96
                        height: 10
                        radius: 5
                        color: root.hatBrimColor
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 20
                        width: 60
                        height: 5
                        color: "#3E2723"
                    }
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

                Rectangle { x: 16; y: 46; width: 16; height: 10; radius: 5; color: root.blushColor; opacity: 0.65 }
                Rectangle { x: 80; y: 46; width: 16; height: 10; radius: 5; color: root.blushColor; opacity: 0.65 }

                // Snout
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 12
                    x: 34 + root.snoutTwitch
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

            // Magnifying Glass
            Item {
                x: 44 + root.glassX
                y: 110
                width: 46
                height: 58
                rotation: root.glassAngle
                transformOrigin: Item.BottomRight

                Rectangle {
                    x: 4; y: 4; width: 34; height: 34; radius: 17
                    color: Qt.rgba(1, 1, 1, 0.25)
                    border.color: root.glassRimColor; border.width: 3.5
                    Rectangle { x: 8; y: 8; width: 8; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.6) }
                }
                Rectangle {
                    x: 28; y: 32; width: 6; height: 22; radius: 3; color: "#5D4037"; rotation: -35
                }
            }
        }

        // ==============================================================
        // 2. ANGLED 3/4 DETECTIVE VIEW (Nghiêng trái / Nghiêng phải)
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

            // Body in trench coat
            Rectangle {
                x: 30; y: 60; width: 120; height: 108; radius: 54; color: root.pigColor
                Rectangle {
                    x: 18; y: 22; width: 80; height: 78; radius: 39; color: "#A1887F"
                }
            }

            // Head 3/4
            Item {
                x: 16; y: 12; width: 108; height: 94

                // Detective Hat Angled
                Item {
                    x: 10; y: -20; width: 90; height: 42
                    Rectangle {
                        x: 16; y: 4; width: 52; height: 26; radius: 7; color: root.hatColor
                    }
                    Rectangle {
                        x: 0; y: 22; width: 86; height: 9; radius: 4.5; color: root.hatBrimColor; rotation: -6
                    }
                    Rectangle {
                        x: 16; y: 19; width: 54; height: 4; color: "#3E2723"
                    }
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

                Rectangle { x: 12; y: 46; width: 14; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.65 }

                // Snout
                Rectangle {
                    x: 0; y: 44; width: 36; height: 26; radius: 13; color: root.snoutColor
                    Rectangle { x: 7; y: 8; width: 5; height: 9; radius: 2.5; color: "#2B1B17" }
                    Rectangle { x: 19; y: 8; width: 4; height: 8; radius: 2; color: "#2B1B17"; opacity: 0.5 }
                }
            }

            // Magnifying Glass angled inspecting ground
            Item {
                x: 16 + root.glassX * 0.7
                y: 114
                width: 44
                height: 56
                rotation: root.glassAngle * 1.2

                Rectangle {
                    x: 2; y: 2; width: 32; height: 32; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.25)
                    border.color: root.glassRimColor; border.width: 3.5
                    Rectangle { x: 6; y: 6; width: 7; height: 7; radius: 3.5; color: Qt.rgba(1, 1, 1, 0.6) }
                }
                Rectangle {
                    x: 24; y: 28; width: 6; height: 20; radius: 3; color: "#5D4037"; rotation: -35
                }
            }
        }

        // ==============================================================
        // 3. BACK VIEW (Detective seen from behind)
        // ==============================================================
        Item {
            id: backView
            anchors.fill: parent
            visible: root.viewAngle === "back"

            // Body in trench coat
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 52
                width: 130
                height: 110
                radius: 55
                color: root.pigColor

                // Coat covering back
                Rectangle {
                    anchors.centerIn: parent
                    width: 118
                    height: 98
                    radius: 49
                    color: "#A1887F"

                    // Waist belt
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 48
                        width: parent.width - 4
                        height: 10
                        radius: 3
                        color: "#8D6E63"
                        border.color: "#6D4C41"; border.width: 1
                    }

                    // Coat vent slit
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 58
                        width: 2.5
                        height: 36
                        color: "#6D4C41"
                    }
                }

                // Wagging tail peeking out
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 30
                    width: 32; height: 32
                    rotation: Math.sin(root.glassAngle) * 25

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

                // Detective Hat Back
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -22
                    width: 100
                    height: 44
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4; width: 60; height: 28; radius: 8; color: root.hatColor
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 24; width: 96; height: 10; radius: 5; color: root.hatBrimColor
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 20; width: 62; height: 5; color: "#3E2723"
                    }
                }

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

            // Magnifying glass peeking on side
            Item {
                x: 125
                y: 110
                width: 36
                height: 46
                rotation: root.glassAngle

                Rectangle {
                    x: 0; y: 0; width: 26; height: 26; radius: 13
                    color: Qt.rgba(1, 1, 1, 0.25)
                    border.color: root.glassRimColor; border.width: 2.5
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggerEureka()
    }
}
