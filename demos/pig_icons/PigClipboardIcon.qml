pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    width: 64
    height: 64

    property bool isCopied: false
    property real stampY: -15
    property real stampOpacity: 0
    property real paperSlideY: 0
    property color pigColor: "#FFB6C1"
    property color clipboardBoardColor: "#B7791F"
    property color paperColor: "#FFFFFF"

    function triggerCopy() {
        copyAnimation.restart();
    }

    SequentialAnimation {
        id: copyAnimation
        running: false

        // 1. Paper slide & bounce
        ParallelAnimation {
            NumberAnimation { target: root; property: "paperSlideY"; from: 8; to: 0; duration: 180; easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "stampOpacity"; from: 0; to: 1; duration: 120 }
            NumberAnimation { target: root; property: "stampY"; from: -14; to: 0; duration: 180; easing.type: Easing.InQuad }
        }
        // Stamp impact bounce!
        ScriptAction { script: root.isCopied = true; }
        PauseAnimation { duration: 400 }
        NumberAnimation { target: root; property: "stampOpacity"; to: 0; duration: 250 }
        NumberAnimation { target: root; property: "stampY"; to: -15; duration: 200 }
    }

    // 1. Wooden Clipboard Base
    Rectangle {
        id: clipboardBase
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 4
        width: parent.width * 0.74
        height: parent.height * 0.82
        radius: 6
        color: root.clipboardBoardColor
        border.width: 1.5
        border.color: "#7B341E"

        // Metallic Clip at top
        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: -4
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.44
            height: 8
            radius: 3
            color: "#A0AEC0"
            border.width: 1
            border.color: "#4A5568"
        }

        // White Paper Sheet
        Rectangle {
            id: paper
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 3 + root.paperSlideY
            width: parent.width * 0.82
            height: parent.height * 0.76
            radius: 3
            color: root.paperColor

            // Document Text Lines
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -4
                spacing: 3.5

                Rectangle { width: paper.width * 0.68; height: 2; radius: 1; color: "#CBD5E0" }
                Rectangle { width: paper.width * 0.54; height: 2; radius: 1; color: "#CBD5E0" }
                Rectangle { width: paper.width * 0.62; height: 2; radius: 1; color: "#CBD5E0" }
            }

            // Stamped Piggy Snout Mark (Appears on copy)
            Text {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 2
                text: "🐽"
                font.pixelSize: 13
                opacity: root.isCopied ? 0.9 : 0.15
                scale: root.isCopied ? 1.0 : 0.6
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            }
        }
    }

    // 2. Piggy Peeking Over Top of Clipboard
    Item {
        id: pigHeader
        anchors.top: parent.top
        anchors.topMargin: -2
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.56
        height: parent.height * 0.38

        // Left Ear
        Rectangle {
            x: parent.width * 0.08
            y: parent.height * 0.08
            width: parent.width * 0.32
            height: parent.height * 0.45
            radius: width / 2
            color: root.pigColor
            rotation: -28
        }
        // Right Ear
        Rectangle {
            x: parent.width * 0.60
            y: parent.height * 0.08
            width: parent.width * 0.32
            height: parent.height * 0.45
            radius: width / 2
            color: root.pigColor
            rotation: 28
        }

        // Pig Head
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.85
            height: parent.height * 0.72
            radius: width / 2
            color: root.pigColor
        }

        // Cute Blinking Eyes
        Rectangle {
            x: parent.width * 0.28
            y: parent.height * 0.52
            width: 3; height: 4; radius: 1.5; color: "#2D1820"
        }
        Rectangle {
            x: parent.width * 0.64
            y: parent.height * 0.52
            width: 3; height: 4; radius: 1.5; color: "#2D1820"
        }

        // Mini Snout
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width * 0.42
            height: parent.height * 0.38
            radius: height / 2
            color: "#FF69B4"

            Row {
                anchors.centerIn: parent
                spacing: 3
                Rectangle { width: 2; height: 3; radius: 1; color: "#501B28" }
                Rectangle { width: 2; height: 3; radius: 1; color: "#501B28" }
            }
        }
    }

    // 3. Piggy Hooves Clamping the Clipboard Edges
    Rectangle {
        x: clipboardBase.x - 3
        y: clipboardBase.y + clipboardBase.height * 0.45
        width: 8
        height: 12
        radius: 4
        color: root.pigColor
        border.width: 1
        border.color: "#E2909C"
    }
    Rectangle {
        x: clipboardBase.x + clipboardBase.width - 5
        y: clipboardBase.y + clipboardBase.height * 0.45
        width: 8
        height: 12
        radius: 4
        color: root.pigColor
        border.width: 1
        border.color: "#E2909C"
    }

    // 4. Stamping Tool (Hoof with stamp slamming down on trigger)
    Rectangle {
        id: stampArm
        visible: root.stampOpacity > 0
        opacity: root.stampOpacity
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.stampY
        width: 16
        height: 20
        radius: 6
        color: "#E53E3E"
        border.width: 1
        border.color: "#9B2C2C"

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: "#FFFFFF"
            font.pixelSize: 11
            font.bold: true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggerCopy()
    }
}
