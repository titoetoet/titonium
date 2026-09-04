pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"

    property color bubbleColor: "#F472B6"

    // Multi-angle perspective: "front" | "left" | "right" | "back"
    property string viewAngle: "front"

    property bool paused: false
    property bool tickled: false

    implicitWidth: 260
    implicitHeight: 250

    property real bellyScale: 1.0
    property real hoofWiggle: 0
    property real gumBubbleSize: 0

    SequentialAnimation {
        running: !root.paused && !root.tickled
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "bellyScale"
                from: 1.0
                to: 1.08
                duration: 1500
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "hoofWiggle"
                from: -6
                to: 6
                duration: 1500
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "gumBubbleSize"
                from: 4
                to: 28
                duration: 2500
                easing.type: Easing.OutQuad
            }
        }

        ScriptAction { script: root.gumBubbleSize = 0 }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "bellyScale"
                from: 1.08
                to: 1.0
                duration: 1500
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: root
                property: "hoofWiggle"
                from: 6
                to: -6
                duration: 1500
                easing.type: Easing.InOutSine
            }
        }
    }

    function tickleBelly() {
        if (root.tickled)
            return;
        root.tickled = true;
        tickleAnim.restart();
    }

    SequentialAnimation {
        id: tickleAnim
        loops: 5
        NumberAnimation { target: root; property: "hoofWiggle"; to: 18; duration: 90 }
        NumberAnimation { target: root; property: "hoofWiggle"; to: -18; duration: 90 }
        onFinished: {
            root.tickled = false;
            for (let i = 0; i < 4; i++) {
                giggleModel.append({
                    symbol: "💖",
                    initX: root.width / 2 + (Math.random() * 30 - 15),
                    initY: root.height / 2,
                    driftX: (Math.random() * 40 - 20)
                });
            }
        }
    }

    ListModel {
        id: giggleModel
    }

    Repeater {
        model: giggleModel
        delegate: Item {
            id: giggleItem
            required property string symbol
            required property real initX
            required property real initY
            required property real driftX
            required property int index

            x: initX
            y: initY

            Text {
                text: giggleItem.symbol
                font.pixelSize: 16
            }

            NumberAnimation on y {
                from: giggleItem.initY
                to: giggleItem.initY - 60
                duration: 1200
                easing.type: Easing.OutQuad
            }
            NumberAnimation on x {
                from: giggleItem.initX
                to: giggleItem.initX + giggleItem.driftX
                duration: 1200
                easing.type: Easing.InOutSine
            }
            NumberAnimation on opacity {
                from: 1.0
                to: 0.0
                duration: 1200
                easing.type: Easing.InQuad
                onFinished: {
                    if (giggleItem.index >= 0 && giggleItem.index < giggleModel.count) {
                        giggleModel.remove(giggleItem.index);
                    }
                }
            }
        }
    }

    Item {
        id: pigRoot
        anchors.centerIn: parent
        width: 200
        height: 160

        // Cozy Floor Mat / Blanket shadow
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 8
            width: 170
            height: 38
            radius: 19
            color: "#1E1A31"
            opacity: 0.8
        }

        // ==============================================================
        // 1. FRONT VIEW
        // ==============================================================
        Item {
            id: frontView
            anchors.fill: parent
            visible: root.viewAngle === "front"

            // Tail wagging on floor
            Canvas {
                x: 8
                y: 95
                width: 32
                height: 28
                rotation: root.hoofWiggle * 2
                transformOrigin: Item.Right
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor;
                    ctx.lineWidth = 4;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    ctx.arc(16, 14, 10, 0, Math.PI * 1.5, false);
                    ctx.stroke();
                }
            }

            // Head resting on ground
            Item {
                id: headGroup
                x: 25
                y: 50
                width: 80
                height: 75

                // Left Ear
                Item {
                    x: -6; y: 12; width: 24; height: 28; rotation: -45
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.fillStyle = root.pigColor;
                            ctx.beginPath(); ctx.moveTo(6, 26); ctx.lineTo(2, 6); ctx.quadraticCurveTo(12, -2, 22, 18); ctx.closePath(); ctx.fill();
                            ctx.fillStyle = root.snoutColor;
                            ctx.beginPath(); ctx.moveTo(8, 22); ctx.lineTo(6, 10); ctx.quadraticCurveTo(12, 6, 18, 18); ctx.closePath(); ctx.fill();
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 74
                    height: 66
                    radius: 33
                    color: root.pigColor
                }

                // Eyes: (^ ^)
                Canvas {
                    x: 18; y: 20; width: 16; height: 12
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = root.eyeColor; ctx.lineWidth = 2.8; ctx.lineCap = "round";
                        ctx.beginPath(); ctx.arc(8, 8, 6, Math.PI, 0, false); ctx.stroke();
                    }
                }
                Canvas {
                    x: 42; y: 20; width: 16; height: 12
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = root.eyeColor; ctx.lineWidth = 2.8; ctx.lineCap = "round";
                        ctx.beginPath(); ctx.arc(8, 8, 6, Math.PI, 0, false); ctx.stroke();
                    }
                }

                Rectangle { x: 10; y: 30; width: 14; height: 8; radius: 4; color: root.blushColor; opacity: 0.7 }
                Rectangle { x: 50; y: 30; width: 14; height: 8; radius: 4; color: root.blushColor; opacity: 0.7 }

                // Snout
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 12
                    width: 36
                    height: 24
                    radius: 12
                    color: root.snoutColor
                    Rectangle { x: 9; y: 7; width: 5; height: 9; radius: 2.5; color: "#2B1B17" }
                    Rectangle { x: 22; y: 7; width: 5; height: 9; radius: 2.5; color: "#2B1B17" }
                }

                // Bubblegum
                Rectangle {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 12
                    width: root.gumBubbleSize
                    height: root.gumBubbleSize
                    radius: width / 2
                    color: Qt.rgba(0.96, 0.45, 0.71, 0.75)
                    border.color: "#FFFFFF"
                    border.width: 1.5
                    visible: root.gumBubbleSize > 2
                    Rectangle {
                        x: parent.width * 0.25; y: parent.height * 0.2
                        width: parent.width * 0.3; height: parent.height * 0.3; radius: width / 2
                        color: "#FFFFFF"; opacity: 0.8
                    }
                }
            }

            // Plump Belly facing up
            Rectangle {
                x: 75
                y: 35
                width: 110
                height: 95
                radius: 48
                color: root.pigColor
                scale: root.bellyScale
                transformOrigin: Item.Bottom

                Rectangle {
                    anchors.centerIn: parent
                    width: 78
                    height: 64
                    radius: 32
                    color: Qt.lighter(root.pigColor, 1.1)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 6; height: 6; radius: 3; color: root.snoutColor
                    }
                }
            }

            // Little Hooves wiggling in air
            Rectangle {
                x: 88; y: 22; width: 16; height: 26; radius: 8; color: root.pigColor
                rotation: -15 + root.hoofWiggle
                Rectangle { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 6; radius: 3; color: root.hoofColor }
            }
            Rectangle {
                x: 118; y: 18; width: 16; height: 26; radius: 8; color: root.pigColor
                rotation: 12 - root.hoofWiggle
                Rectangle { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 6; radius: 3; color: root.hoofColor }
            }
            Rectangle {
                x: 148; y: 24; width: 16; height: 26; radius: 8; color: root.pigColor
                rotation: 25 + root.hoofWiggle
                Rectangle { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 6; radius: 3; color: root.hoofColor }
            }
        }

        // ==============================================================
        // 2. ANGLED 3/4 LOUNGING VIEW (Nghiêng trái / Nghiêng phải)
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
                x: 155; y: 92; width: 32; height: 28
                rotation: root.hoofWiggle * 2
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = root.pigColor; ctx.lineWidth = 4; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.arc(16, 14, 10, 0, Math.PI * 1.5, false); ctx.stroke();
                }
            }

            // Head 3/4 resting on floor
            Item {
                x: 20
                y: 52
                width: 76
                height: 70

                Rectangle {
                    anchors.centerIn: parent
                    width: 70; height: 62; radius: 31; color: root.pigColor
                }

                // Eye (^ profile)
                Canvas {
                    x: 16; y: 18; width: 16; height: 12
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = root.eyeColor; ctx.lineWidth = 2.8; ctx.lineCap = "round";
                        ctx.beginPath(); ctx.arc(8, 8, 6, Math.PI, 0, false); ctx.stroke();
                    }
                }

                Rectangle { x: 8; y: 28; width: 12; height: 7; radius: 3.5; color: root.blushColor; opacity: 0.7 }

                // Snout profile tilted up
                Rectangle {
                    x: 0; y: 24; width: 28; height: 20; radius: 10; color: root.snoutColor
                    Rectangle { x: 6; y: 5; width: 4; height: 7; radius: 2; color: "#2B1B17" }
                }

                // Bubblegum angled
                Rectangle {
                    x: -root.gumBubbleSize * 0.3; y: 16 - root.gumBubbleSize * 0.5
                    width: root.gumBubbleSize; height: root.gumBubbleSize; radius: width / 2
                    color: Qt.rgba(0.96, 0.45, 0.71, 0.75)
                    border.color: "#FFFFFF"; border.width: 1.5
                    visible: root.gumBubbleSize > 2
                }
            }

            // Body resting sideways
            Rectangle {
                x: 65; y: 40; width: 105; height: 90; radius: 45; color: root.pigColor
                scale: root.bellyScale
                transformOrigin: Item.Bottom
                Rectangle {
                    x: 14; y: 12; width: 70; height: 58; radius: 29
                    color: Qt.lighter(root.pigColor, 1.1)
                }
            }

            // Hooves resting & kicking up
            Rectangle {
                x: 95; y: 24; width: 16; height: 26; radius: 8; color: root.pigColor
                rotation: -8 + root.hoofWiggle
                Rectangle { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 6; radius: 3; color: root.hoofColor }
            }
            Rectangle {
                x: 130; y: 26; width: 16; height: 26; radius: 8; color: root.pigColor
                rotation: 18 - root.hoofWiggle
                Rectangle { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 6; radius: 3; color: root.hoofColor }
            }
        }

        // ==============================================================
        // 3. BACK VIEW (Lounging pig seen from rear/back perspective)
        // ==============================================================
        Item {
            id: backView
            anchors.fill: parent
            visible: root.viewAngle === "back"

            // Plump Piggy Bottom & Back resting on mat
            Rectangle {
                anchors.centerIn: parent
                y: 40
                width: 130
                height: 96
                radius: 48
                color: root.pigColor

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Qt.darker(root.pigColor, 1.1);
                        ctx.lineWidth = 2.5;
                        ctx.beginPath();
                        ctx.moveTo(width / 2, 50); ctx.lineTo(width / 2, 75); ctx.stroke();
                    }
                }

                // Wagging tail right in center
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 24
                    width: 32; height: 32
                    rotation: root.hoofWiggle * 4

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

            // Back of Head
            Item {
                x: 20
                y: 55
                width: 65
                height: 60

                Rectangle {
                    anchors.fill: parent
                    radius: 30
                    color: root.pigColor
                }

                // Bubblegum balloon peeking from behind the head!
                Rectangle {
                    x: -8; y: -root.gumBubbleSize * 0.4
                    width: root.gumBubbleSize; height: root.gumBubbleSize; radius: width / 2
                    color: Qt.rgba(0.96, 0.45, 0.71, 0.75)
                    border.color: "#FFFFFF"; border.width: 1.5
                    visible: root.gumBubbleSize > 4
                }
            }

            // Back of little hooves wiggling up
            Rectangle {
                x: 95; y: 28; width: 14; height: 22; radius: 7; color: root.pigColor
                rotation: -10 + root.hoofWiggle
                Rectangle { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: 9; height: 5; radius: 2.5; color: root.hoofColor }
            }
            Rectangle {
                x: 125; y: 28; width: 14; height: 22; radius: 7; color: root.pigColor
                rotation: 15 - root.hoofWiggle
                Rectangle { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: 9; height: 5; radius: 2.5; color: root.hoofColor }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.tickleBelly()
    }
}
