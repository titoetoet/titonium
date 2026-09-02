pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    width: 64
    height: 64

    property bool ringing: false
    property int unreadCount: 1
    property real bellAngle: 0
    property real earLift: 0
    property color pigColor: "#FFB6C1"
    property color bellColor: "#ECC94B"

    function ring() {
        ringAnimation.restart();
    }

    // Bell Swing & Ringing Animation
    SequentialAnimation {
        id: ringAnimation
        running: root.ringing
        loops: root.ringing ? Animation.Infinite : 1

        ScriptAction { script: root.earLift = 10; }
        NumberAnimation { target: root; property: "bellAngle"; from: 0; to: -24; duration: 80; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bellAngle"; from: -24; to: 24; duration: 160; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "bellAngle"; from: 24; to: -18; duration: 140; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "bellAngle"; from: -18; to: 16; duration: 120; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "bellAngle"; from: 16; to: -8; duration: 100; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "bellAngle"; from: -8; to: 0; duration: 90; easing.type: Easing.OutQuad }
        ScriptAction { script: root.earLift = 0; }
    }

    // Soundwave ripples
    Item {
        id: soundwaves
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        opacity: Math.abs(root.bellAngle) > 8 ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: ")))"
            color: "#ECC94B"
            font.pixelSize: 11
            font.bold: true
            rotation: 180
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: ")))"
            color: "#ECC94B"
            font.pixelSize: 11
            font.bold: true
        }
    }

    // Piggy Mascot Base
    Item {
        id: pigBase
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: parent.height * 0.8

        // Left Floppy Ear (perks up when ringing)
        Rectangle {
            x: parent.width * 0.12
            y: parent.height * 0.08 - root.earLift
            width: parent.width * 0.26
            height: parent.height * 0.26
            radius: width / 2
            color: root.pigColor
            rotation: -25 - root.earLift
            transformOrigin: Item.BottomRight
            Behavior on y { NumberAnimation { duration: 120 } }
            Behavior on rotation { NumberAnimation { duration: 120 } }
        }

        // Right Floppy Ear (perks up when ringing)
        Rectangle {
            x: parent.width * 0.62
            y: parent.height * 0.08 - root.earLift
            width: parent.width * 0.26
            height: parent.height * 0.26
            radius: width / 2
            color: root.pigColor
            rotation: 25 + root.earLift
            transformOrigin: Item.BottomLeft
            Behavior on y { NumberAnimation { duration: 120 } }
            Behavior on rotation { NumberAnimation { duration: 120 } }
        }

        // Head
        Rectangle {
            id: head
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -4
            width: parent.width * 0.72
            height: parent.height * 0.64
            radius: width / 2
            color: root.pigColor
        }

        // Eyes
        Rectangle {
            x: head.x + head.width * 0.24
            y: head.y + head.height * 0.32
            width: 4; height: 5; radius: 2; color: "#2D1820"
        }
        Rectangle {
            x: head.x + head.width * 0.68
            y: head.y + head.height * 0.32
            width: 4; height: 5; radius: 2; color: "#2D1820"
        }

        // Snout
        Rectangle {
            anchors.horizontalCenter: head.horizontalCenter
            y: head.y + head.height * 0.44
            width: head.width * 0.42
            height: head.height * 0.34
            radius: height / 2
            color: "#FF69B4"

            Row {
                anchors.centerIn: parent
                spacing: parent.width * 0.25
                Rectangle { width: 3; height: 4; radius: 2; color: "#501B28" }
                Rectangle { width: 3; height: 4; radius: 2; color: "#501B28" }
            }
        }
    }

    // Golden Bell in Front of Pig (Swinging)
    Item {
        id: bellContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: parent.width * 0.52
        height: parent.height * 0.48
        rotation: root.bellAngle
        transformOrigin: Item.Top

        Canvas {
            id: bellCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = bellCanvas.getContext("2d");
                ctx.clearRect(0, 0, width, height);

                // Bell Body (Golden Dome Flaring to Rim)
                ctx.fillStyle = root.bellColor;
                ctx.beginPath();
                ctx.moveTo(width * 0.5, 2);
                ctx.bezierCurveTo(width * 0.15, height * 0.15, width * 0.1, height * 0.75, 2, height * 0.85);
                ctx.lineTo(width - 2, height * 0.85);
                ctx.bezierCurveTo(width * 0.9, height * 0.75, width * 0.85, height * 0.15, width * 0.5, 2);
                ctx.fill();

                // Bell Rim
                ctx.fillStyle = "#D69E2E";
                ctx.beginPath();
                ctx.rect(0, height * 0.82, width, height * 0.14);
                ctx.fill();

                // Clapper (Ball at bottom)
                ctx.fillStyle = "#B7791F";
                ctx.beginPath();
                ctx.arc(width * 0.5, height * 0.94, width * 0.12, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    // Notification Dot / Badge
    Rectangle {
        id: badge
        visible: root.unreadCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 3
        width: Math.max(16, badgeText.contentWidth + 8)
        height: 16
        radius: 8
        color: "#E53E3E"
        border.width: 1.5
        border.color: "#FFFFFF"

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.unreadCount > 99 ? "99+" : String(root.unreadCount)
            color: "#FFFFFF"
            font.pixelSize: 9
            font.bold: true
        }

        // Bouncing pulse on new unread
        SequentialAnimation on scale {
            running: root.unreadCount > 0
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.16; duration: 800; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.16; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.ring()
    }
}
