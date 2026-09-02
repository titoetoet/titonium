pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    width: 64
    height: 64

    property bool active: true
    property real breathing: 1.0
    property real auraRotation: 0
    property bool eyesOpen: false
    property color pigColor: "#FFB6C1"
    property color headbandColor: "#FFFFFF"
    property color focusAccent: "#00F2FE"

    // Zen Breathing Micro-Animation
    SequentialAnimation on breathing {
        running: root.active
        loops: Animation.Infinite
        NumberAnimation { from: 0.94; to: 1.06; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.06; to: 0.94; duration: 1600; easing.type: Easing.InOutSine }
    }

    // Rotating Focus Ring Aura
    NumberAnimation on auraRotation {
        running: root.active
        from: 0
        to: 360
        duration: 8000
        loops: Animation.Infinite
    }

    // 1. Outer Focus Ring (Target / Crosshairs)
    Item {
        id: focusRing
        anchors.fill: parent
        rotation: root.auraRotation
        opacity: root.active ? 0.75 : 0.25
        Behavior on opacity { NumberAnimation { duration: 300 } }

        Canvas {
            id: ringCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = ringCanvas.getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const cx = width / 2;
                const cy = height / 2;
                const r = Math.min(cx, cy) - 3;

                // Glowing circular ring
                ctx.strokeStyle = root.focusAccent;
                ctx.lineWidth = 1.8;
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.stroke();

                // 4 Focus Tick Marks (Crosshairs)
                ctx.lineWidth = 2.5;
                const ticks = [0, Math.PI / 2, Math.PI, Math.PI * 1.5];
                ticks.forEach(angle => {
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(angle) * (r - 4), cy + Math.sin(angle) * (r - 4));
                    ctx.lineTo(cx + Math.cos(angle) * (r + 4), cy + Math.sin(angle) * (r + 4));
                    ctx.stroke();
                });
            }
        }
    }

    // 2. Focused Piggy Mascot
    Item {
        id: pigMascot
        anchors.centerIn: parent
        width: parent.width * 0.76
        height: parent.height * 0.76
        scale: root.breathing

        // Left Ear
        Rectangle {
            x: parent.width * 0.12
            y: parent.height * 0.08
            width: parent.width * 0.24
            height: parent.height * 0.24
            radius: width / 2
            color: root.pigColor
            rotation: -30
        }

        // Right Ear
        Rectangle {
            x: parent.width * 0.64
            y: parent.height * 0.08
            width: parent.width * 0.24
            height: parent.height * 0.24
            radius: width / 2
            color: root.pigColor
            rotation: 30
        }

        // Head
        Rectangle {
            id: head
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            width: parent.width * 0.8
            height: parent.height * 0.74
            radius: width / 2
            color: root.pigColor
        }

        // Focus Headband (Hachimaki) across forehead
        Rectangle {
            id: headband
            anchors.horizontalCenter: head.horizontalCenter
            y: head.y + head.height * 0.18
            width: head.width * 0.96
            height: head.height * 0.16
            radius: 4
            color: root.headbandColor

            // Red focus dot in center of headband
            Rectangle {
                anchors.centerIn: parent
                width: parent.height * 0.65
                height: width
                radius: width / 2
                color: "#E53E3E"
            }
        }

        // Left Eye (Zen Closed Arc or Open Dot)
        Item {
            x: head.x + head.width * 0.24
            y: head.y + head.height * 0.44
            width: head.width * 0.16
            height: width

            Text {
                anchors.centerIn: parent
                text: root.eyesOpen ? "●" : "⌒"
                font.bold: true
                font.pixelSize: root.eyesOpen ? 10 : 13
                color: "#2D1820"
            }
        }

        // Right Eye
        Item {
            x: head.x + head.width * 0.60
            y: head.y + head.height * 0.44
            width: head.width * 0.16
            height: width

            Text {
                anchors.centerIn: parent
                text: root.eyesOpen ? "●" : "⌒"
                font.bold: true
                font.pixelSize: root.eyesOpen ? 10 : 13
                color: "#2D1820"
            }
        }

        // Cheeks
        Rectangle {
            x: head.x + head.width * 0.14
            y: head.y + head.height * 0.54
            width: head.width * 0.18
            height: head.height * 0.10
            radius: height / 2
            color: "#FF4D80"
            opacity: 0.65
        }
        Rectangle {
            x: head.x + head.width * 0.68
            y: head.y + head.height * 0.54
            width: head.width * 0.18
            height: head.height * 0.10
            radius: height / 2
            color: "#FF4D80"
            opacity: 0.65
        }

        // Snout
        Rectangle {
            anchors.horizontalCenter: head.horizontalCenter
            y: head.y + head.height * 0.52
            width: head.width * 0.36
            height: head.height * 0.26
            radius: height / 2
            color: "#FF69B4"

            // Nostrils
            Row {
                anchors.centerIn: parent
                spacing: parent.width * 0.25
                Rectangle { width: 3; height: 5; radius: 2; color: "#501B28" }
                Rectangle { width: 3; height: 5; radius: 2; color: "#501B28" }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.eyesOpen = true
        onExited: root.eyesOpen = false
        onClicked: root.active = !root.active
    }
}
