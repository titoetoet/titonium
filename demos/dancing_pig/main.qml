pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: appWindow
    width: 320
    height: 270
    minimumWidth: 320
    maximumWidth: 320
    minimumHeight: 270
    maximumHeight: 270
    visible: true
    title: "🐷 Dancing Pig"
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.Window

    property string danceMode: "walk"
    readonly property var danceModes: ["disco", "hop", "walk", "wiggle"]

    function nextDance() {
        const idx = danceModes.indexOf(danceMode);
        danceMode = danceModes[(idx + 1) % danceModes.length];
        pig.cheer();
    }

    // Drag to move the pig anywhere on the desktop (Wayland/X11 native window move)
    DragHandler {
        onActiveChanged: {
            if (active) {
                appWindow.startSystemMove();
            }
        }
    }

    // Interactive Pig Area (Click to cheer & cycle dance moves)
    DancingPig {
        id: pig
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 260
        height: 215
        danceStyle: appWindow.danceMode
        bpm: 130
        showShadow: false

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: appWindow.nextDance()
        }
    }

    // Close Button (Subtle, top-right)
    Rectangle {
        id: closeBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        width: 22
        height: 22
        radius: 11
        color: closeMouse.containsMouse ? "#E53E3E" : "#40000000"
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "#FFFFFF"
            font.pixelSize: 11
            font.bold: true
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: appWindow.close()
        }
    }

    // Minimal Dance Moves Selector (Floating pill at bottom)
    Rectangle {
        id: controlsPill
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: 290
        height: 36
        radius: 18
        color: "#D01A1826"
        border.width: 1
        border.color: "#40FFFFFF"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 3

            // 1. Disco
            Button {
                id: discoBtn
                text: "🕺 Disco"
                Layout.fillWidth: true
                Layout.fillHeight: true
                checked: appWindow.danceMode === "disco"
                contentItem: Text {
                    text: discoBtn.text
                    color: discoBtn.checked ? "#FFFFFF" : "#A0AEC0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    font.bold: discoBtn.checked
                }
                background: Rectangle {
                    color: discoBtn.checked ? "#7928CA" : (discoBtn.hovered ? "#30FFFFFF" : "transparent")
                    radius: 14
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                onClicked: appWindow.danceMode = "disco"
            }

            // 2. Hop Hop
            Button {
                id: hopBtn
                text: "🦘 Hop"
                Layout.fillWidth: true
                Layout.fillHeight: true
                checked: appWindow.danceMode === "hop"
                contentItem: Text {
                    text: hopBtn.text
                    color: hopBtn.checked ? "#FFFFFF" : "#A0AEC0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    font.bold: hopBtn.checked
                }
                background: Rectangle {
                    color: hopBtn.checked ? "#7928CA" : (hopBtn.hovered ? "#30FFFFFF" : "transparent")
                    radius: 14
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                onClicked: appWindow.danceMode = "hop"
            }

            // 3. Walk (Đi dạo)
            Button {
                id: walkBtn
                text: "🚶 Đi dạo"
                Layout.fillWidth: true
                Layout.fillHeight: true
                checked: appWindow.danceMode === "walk"
                contentItem: Text {
                    text: walkBtn.text
                    color: walkBtn.checked ? "#FFFFFF" : "#A0AEC0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    font.bold: walkBtn.checked
                }
                background: Rectangle {
                    color: walkBtn.checked ? "#7928CA" : (walkBtn.hovered ? "#30FFFFFF" : "transparent")
                    radius: 14
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                onClicked: appWindow.danceMode = "walk"
            }

            // 4. Wiggle (Lắc lư)
            Button {
                id: wiggleBtn
                text: "🌊 Lắc lư"
                Layout.fillWidth: true
                Layout.fillHeight: true
                checked: appWindow.danceMode === "wiggle"
                contentItem: Text {
                    text: wiggleBtn.text
                    color: wiggleBtn.checked ? "#FFFFFF" : "#A0AEC0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 11
                    font.bold: wiggleBtn.checked
                }
                background: Rectangle {
                    color: wiggleBtn.checked ? "#7928CA" : (wiggleBtn.hovered ? "#30FFFFFF" : "transparent")
                    radius: 14
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                onClicked: appWindow.danceMode = "wiggle"
            }
        }
    }
}
