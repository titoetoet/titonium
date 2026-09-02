pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root
    width: 64
    height: 64

    // State: "pending", "granted", "denied", "idle"
    property string status: "pending"
    property real scanPos: 0
    property real shieldPulse: 1.0
    property real headShake: 0
    property color pigColor: "#FFB6C1"
    property color cyberColor: "#00F2FE"

    function request() {
        root.status = "pending";
    }

    function approve() {
        root.status = "granted";
    }

    function deny() {
        root.status = "denied";
        denyShake.restart();
    }

    // Visor Laser Scanning Animation
    SequentialAnimation on scanPos {
        running: root.status === "pending"
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 900; easing.type: Easing.InOutSine }
    }

    // Shield Hologram Pulsing
    SequentialAnimation on shieldPulse {
        running: root.status === "pending"
        loops: Animation.Infinite
        NumberAnimation { from: 0.95; to: 1.12; duration: 750; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.12; to: 0.95; duration: 750; easing.type: Easing.InOutSine }
    }

    // Deny Head Shake
    SequentialAnimation {
        id: denyShake
        running: false
        NumberAnimation { target: root; property: "headShake"; from: 0; to: -12; duration: 60 }
        NumberAnimation { target: root; property: "headShake"; from: -12; to: 12; duration: 120 }
        NumberAnimation { target: root; property: "headShake"; from: 12; to: -8; duration: 100 }
        NumberAnimation { target: root; property: "headShake"; from: -8; to: 0; duration: 80 }
    }

    // Mascot Group with Head Shake
    Item {
        id: mascot
        anchors.centerIn: parent
        width: parent.width * 0.82
        height: parent.height * 0.82
        rotation: root.headShake

        // 1. Cyber Antenna on Head
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -4
            width: 3
            height: 10
            color: "#718096"

            // Antenna Blinking LED Bulb
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: -5
                anchors.horizontalCenter: parent.horizontalCenter
                width: 9
                height: 9
                radius: 4.5
                color: {
                    if (root.status === "granted") return "#48BB78";
                    if (root.status === "denied") return "#F56565";
                    return "#ED8936"; // Pending amber
                }

                // Blinking Pulse on Antenna
                SequentialAnimation on opacity {
                    running: root.status === "pending"
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.3; duration: 450 }
                    NumberAnimation { from: 0.3; to: 1.0; duration: 450 }
                }
            }
        }

        // Left Ear
        Rectangle {
            x: parent.width * 0.12
            y: parent.height * 0.12
            width: parent.width * 0.26
            height: parent.height * 0.28
            radius: width / 2
            color: root.pigColor
            rotation: -28
        }
        // Right Ear
        Rectangle {
            x: parent.width * 0.62
            y: parent.height * 0.12
            width: parent.width * 0.26
            height: parent.height * 0.28
            radius: width / 2
            color: root.pigColor
            rotation: 28
        }

        // Head
        Rectangle {
            id: head
            anchors.centerIn: parent
            width: parent.width * 0.78
            height: parent.height * 0.72
            radius: width / 2
            color: root.pigColor
        }

        // 2. Futuristic Cyber Visor across eyes
        Rectangle {
            id: visor
            anchors.horizontalCenter: head.horizontalCenter
            y: head.y + head.height * 0.24
            width: head.width * 0.88
            height: head.height * 0.24
            radius: 5
            color: "#1A202C"
            border.width: 1.2
            border.color: root.status === "granted" ? "#48BB78" : (root.status === "denied" ? "#E53E3E" : root.cyberColor)

            // Scanning Beam Line
            Rectangle {
                visible: root.status === "pending"
                x: (parent.width - width) * root.scanPos
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: parent.height - 2
                radius: 2
                color: root.cyberColor
                opacity: 0.85
            }

            // Visor Display Text / Status Icon
            Text {
                anchors.centerIn: parent
                visible: root.status !== "pending"
                text: root.status === "granted" ? "GRANTED" : "DENIED"
                color: root.status === "granted" ? "#48BB78" : "#E53E3E"
                font.pixelSize: 8
                font.bold: true
            }
        }

        // Snout
        Rectangle {
            anchors.horizontalCenter: head.horizontalCenter
            y: head.y + head.height * 0.52
            width: head.width * 0.44
            height: head.height * 0.32
            radius: height / 2
            color: "#FF69B4"

            Row {
                anchors.centerIn: parent
                spacing: 4
                Rectangle { width: 3; height: 4; radius: 1.5; color: "#501B28" }
                Rectangle { width: 3; height: 4; radius: 1.5; color: "#501B28" }
            }
        }

        // 3. Holographic Security Shield Badge
        Rectangle {
            id: holoShield
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -2
            anchors.right: parent.right
            anchors.rightMargin: -2
            width: 24
            height: 24
            radius: 12
            scale: root.shieldPulse
            color: root.status === "granted" ? "#22543D" : (root.status === "denied" ? "#742A2A" : "#1A365D")
            border.width: 1.5
            border.color: root.status === "granted" ? "#48BB78" : (root.status === "denied" ? "#F56565" : root.cyberColor)

            Text {
                anchors.centerIn: parent
                text: root.status === "granted" ? "🛡️" : (root.status === "denied" ? "🚫" : "⚡")
                font.pixelSize: 11
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.status === "pending") root.approve();
            else if (root.status === "granted") root.deny();
            else root.request();
        }
    }
}
