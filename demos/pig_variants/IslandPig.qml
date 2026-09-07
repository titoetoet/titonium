pragma ComponentBehavior: Bound

import QtQuick
import "../../Titonium/Shared/Mascots/Pig" as Pig

Item {
    id: root

    property color pigColor: "#FFB6C1"
    property color snoutColor: "#FF69B4"
    property color blushColor: "#FF3366"
    property color eyeColor: "#2B1B17"
    property color hoofColor: "#3D2329"

    // Chế độ hiển thị:
    // "roam"  : Tung tăng bên trong Center Island (Mini Pig đi dạo, chạy nhảy, đổi random hành động)
    // "cling" : Ôm viền ngoài Center Island (Ẩn người sau pill, ló mặt & tay các góc)
    property string displayMode: "roam"

    // Vị trí khi ở chế độ "cling":
    // "bottom" | "left" | "right" | "bottom-left" | "bottom-right" | "peekaboo"
    property string islandPosition: "bottom"

    // Hành động hiện tại khi ở chế độ "roam":
    // "random" | "walking" | "running" | "coffee" | "coder" | "detective" | "gym" | "lying" | "sleepy"
    property string roamAction: "random"

    property bool paused: false
    property bool isScared: false

    // Kích thước Center Island
    property real islandWidth: 460
    property real islandHeight: 56
    property real islandRadius: 28

    implicitWidth: 500
    implicitHeight: 280

    // =========================================================================
    // ROAM STATE MACHINE (Hệ thống tung tăng ngẫu nhiên trong Island)
    // =========================================================================
    property string activeRoamAction: "walking"
    readonly property var availableActions: [
        "walking", "running", "coffee", "coder", "detective", "gym", "lying", "sleepy"
    ]

    property real pigX: 50
    property int pigDir: 1 // 1: đi sang phải, -1: đi sang trái
    property real moveSpeed: 1.2
    property bool isJumping: false
    property real jumpY: 0

    // Cập nhật vị trí di chuyển khi đang walking hoặc running
    Timer {
        interval: 33 // ~30 FPS
        running: !root.paused && root.displayMode === "roam" && (root.activeRoamAction === "walking" || root.activeRoamAction === "running")
        repeat: true
        onTriggered: {
            const minX = 35;
            const maxX = root.islandWidth - 75;
            const speed = (root.activeRoamAction === "running" ? 2.8 : 1.2) * root.pigDir;
            root.pigX += speed;

            if (root.pigX >= maxX) {
                root.pigX = maxX;
                root.pigDir = -1;
                root.maybeChangeAction();
            } else if (root.pigX <= minX) {
                root.pigX = minX;
                root.pigDir = 1;
                root.maybeChangeAction();
            }
        }
    }

    // Timer tự động đổi hành động ngẫu nhiên khi roamAction === "random"
    Timer {
        id: randomActionTimer
        interval: 4000
        running: !root.paused && root.displayMode === "roam" && root.roamAction === "random"
        repeat: true
        onTriggered: root.pickRandomAction()
    }

    function maybeChangeAction() {
        if (root.roamAction === "random" && Math.random() > 0.45) {
            root.pickRandomAction();
        }
    }

    function pickRandomAction() {
        if (root.roamAction !== "random") {
            root.activeRoamAction = root.roamAction;
            return;
        }
        // Chọn ngẫu nhiên 1 hành động mới khác hành động hiện tại
        let next = root.activeRoamAction;
        while (next === root.activeRoamAction) {
            const idx = Math.floor(Math.random() * root.availableActions.length);
            next = root.availableActions[idx];
        }
        root.activeRoamAction = next;

        // Tùy chỉnh thời gian lưu lại cho mỗi hành động
        if (next === "walking") {
            randomActionTimer.interval = 4000 + Math.random() * 2500;
        } else if (next === "running") {
            randomActionTimer.interval = 3000 + Math.random() * 2000;
        } else if (next === "lying" || next === "sleepy") {
            randomActionTimer.interval = 4500 + Math.random() * 2000;
        } else {
            randomActionTimer.interval = 3800 + Math.random() * 2000;
        }
    }

    onRoamActionChanged: {
        if (root.roamAction === "random") {
            root.pickRandomAction();
        } else {
            root.activeRoamAction = root.roamAction;
        }
    }

    // Nhảy cẫng lên khi tương tác
    function triggerJump() {
        if (root.isJumping) return;
        root.isJumping = true;
        jumpAnim.restart();
    }

    SequentialAnimation {
        id: jumpAnim
        NumberAnimation { target: root; property: "jumpY"; to: -16; duration: 160; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "jumpY"; to: 0; duration: 200; easing.type: Easing.OutBounce }
        ScriptAction {
            script: {
                root.isJumping = false;
                for (let i = 0; i < 4; i++) {
                    heartModel.append({
                        symbol: "✨",
                        initX: islandRoot.x + root.pigX + 15,
                        initY: islandRoot.y + 10,
                        driftX: (Math.random() * 40 - 20)
                    });
                }
            }
        }
    }

    // Tên mô tả hành động hiện tại
    readonly property string actionTitle: {
        switch (root.activeRoamAction) {
            case "walking": return "🚶 Đi dạo lon ton";
            case "running": return "🏃 Chạy tung tăng";
            case "coffee": return "🧋 Uống trà sữa boba";
            case "coder": return "💻 Turbo code mini";
            case "detective": return "🔍 Soi kính lúp thám tử";
            case "gym": return "🏋️ Tập tạ nâng cơ";
            case "lying": return "🛌 Nằm phơi bụng";
            case "sleepy": return "😴 Ngủ nướng êm dịu";
            default: return "🐷 Tung tăng";
        }
    }

    // =========================================================================
    // CLING VARIABLES (Chế độ ôm viền)
    // =========================================================================
    property real peekOffset: 0
    property real earWiggle: 0
    property real eyeBlink: 1.0
    property real hoofTension: 0

    SequentialAnimation {
        running: !root.paused && !root.isScared && root.displayMode === "cling"
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation { target: root; property: "peekOffset"; to: 9; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "earWiggle"; to: 6; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "hoofTension"; to: 2.5; duration: 1800; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "peekOffset"; to: 0; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "earWiggle"; to: -4; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { target: root; property: "hoofTension"; to: 0; duration: 1800; easing.type: Easing.InOutSine }
        }
    }

    // Blink timer
    Timer {
        interval: 3400
        running: !root.paused
        repeat: true
        onTriggered: blinkAnim.restart()
    }

    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: root; property: "eyeBlink"; to: 0.08; duration: 80 }
        NumberAnimation { target: root; property: "eyeBlink"; to: 1.0; duration: 130 }
    }

    property int autoCycleIndex: 0
    readonly property var positionCycle: ["bottom", "left", "bottom-left", "right", "bottom-right"]

    Timer {
        interval: 2600
        running: root.islandPosition === "peekaboo" && !root.paused && root.displayMode === "cling"
        repeat: true
        onTriggered: {
            root.autoCycleIndex = (root.autoCycleIndex + 1) % root.positionCycle.length;
        }
    }

    readonly property string effectivePosition:
        root.islandPosition === "peekaboo"
            ? root.positionCycle[root.autoCycleIndex]
            : root.islandPosition

    function triggerScare() {
        if (root.displayMode === "roam") {
            root.triggerJump();
            return;
        }
        if (root.isScared) return;
        root.isScared = true;
        scareAnim.restart();
    }

    SequentialAnimation {
        id: scareAnim
        NumberAnimation { target: root; property: "peekOffset"; to: -45; duration: 220; easing.type: Easing.InQuad }
        PauseAnimation { duration: 380 }
        NumberAnimation { target: root; property: "peekOffset"; to: 0; duration: 520; easing.type: Easing.OutBack }
        ScriptAction {
            script: {
                root.isScared = false;
                for (let i = 0; i < 4; i++) {
                    heartModel.append({
                        symbol: "💖",
                        initX: root.width / 2 + (Math.random() * 80 - 40),
                        initY: islandRoot.y + root.islandHeight + 12,
                        driftX: (Math.random() * 40 - 20)
                    });
                }
            }
        }
    }

    ListModel { id: heartModel }

    Repeater {
        model: heartModel
        delegate: Item {
            id: heartItem
            required property string symbol
            required property real initX
            required property real initY
            required property real driftX
            required property int index

            x: initX
            y: initY

            Text { text: heartItem.symbol; font.pixelSize: 16 }

            NumberAnimation on y {
                from: heartItem.initY; to: heartItem.initY + 45; duration: 1100; easing.type: Easing.OutQuad
            }
            NumberAnimation on x {
                from: heartItem.initX; to: heartItem.initX + heartItem.driftX; duration: 1100; easing.type: Easing.InOutSine
            }
            NumberAnimation on opacity {
                from: 1.0; to: 0.0; duration: 1100; easing.type: Easing.InQuad
                onFinished: {
                    if (heartItem.index >= 0 && heartItem.index < heartModel.count) heartModel.remove(heartItem.index);
                }
            }
        }
    }

    // =========================================================================
    // LAYER 1: CLINGING MODE (Khi ở chế độ ôm viền, nằm phía sau Center Island)
    // =========================================================================
    Item {
        id: behindLayer
        anchors.fill: parent
        visible: root.displayMode === "cling"

        // 1. Bottom
        Item {
            visible: root.effectivePosition === "bottom"
            anchors.horizontalCenter: parent.horizontalCenter
            y: islandRoot.y + root.islandHeight - 34 + root.peekOffset
            width: 140
            height: 120

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter; y: -20; width: 116; height: 70; radius: 35; color: root.pigColor
            }

            Item {
                x: 10; y: 2; width: 28; height: 34; rotation: -28 + root.earWiggle; transformOrigin: Item.BottomRight
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d"); ctx.clearRect(0, 0, width, height); ctx.fillStyle = root.pigColor;
                        ctx.beginPath(); ctx.moveTo(8, 32); ctx.lineTo(2, 6); ctx.quadraticCurveTo(15, -2, 26, 22); ctx.closePath(); ctx.fill();
                        ctx.fillStyle = root.snoutColor; ctx.beginPath(); ctx.moveTo(10, 26); ctx.lineTo(8, 12); ctx.quadraticCurveTo(15, 8, 20, 22); ctx.closePath(); ctx.fill();
                    }
                }
            }
            Item {
                x: 102; y: 2; width: 28; height: 34; rotation: 28 - root.earWiggle; transformOrigin: Item.BottomLeft
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d"); ctx.clearRect(0, 0, width, height); ctx.fillStyle = root.pigColor;
                        ctx.beginPath(); ctx.moveTo(20, 32); ctx.lineTo(26, 6); ctx.quadraticCurveTo(15, -2, 2, 22); ctx.closePath(); ctx.fill();
                        ctx.fillStyle = root.snoutColor; ctx.beginPath(); ctx.moveTo(18, 26); ctx.lineTo(20, 12); ctx.quadraticCurveTo(15, 8, 8, 22); ctx.closePath(); ctx.fill();
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 102; height: 84; radius: 42; color: root.pigColor
                Item {
                    x: 23; y: 26; width: 16; height: 16; scale: root.eyeBlink; transformOrigin: Item.Center
                    Rectangle { anchors.fill: parent; radius: 8; color: root.eyeColor; Rectangle { x: 3; y: 5; width: 4.5; height: 4.5; radius: 2.25; color: "#FFFFFF" } }
                }
                Item {
                    x: 63; y: 26; width: 16; height: 16; scale: root.eyeBlink; transformOrigin: Item.Center
                    Rectangle { anchors.fill: parent; radius: 8; color: root.eyeColor; Rectangle { x: 3; y: 5; width: 4.5; height: 4.5; radius: 2.25; color: "#FFFFFF" } }
                }
                Rectangle { x: 12; y: 38; width: 15; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.7 }
                Rectangle { x: 75; y: 38; width: 15; height: 9; radius: 4.5; color: root.blushColor; opacity: 0.7 }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter; y: 38; width: 44; height: 28; radius: 14; color: root.snoutColor
                    Rectangle { anchors.top: parent.top; anchors.topMargin: 2; anchors.horizontalCenter: parent.horizontalCenter; width: 20; height: 4; radius: 2; color: "#50FFFFFF" }
                    Rectangle { x: 11; y: 8; width: 6; height: 10; radius: 3; color: "#2B1B17" }
                    Rectangle { x: 27; y: 8; width: 6; height: 10; radius: 3; color: "#2B1B17" }
                }
            }
        }

        // 2. Left
        Item {
            visible: root.effectivePosition === "left"
            x: islandRoot.x - 76 - root.peekOffset; y: islandRoot.y - 12; width: 100; height: 90
            Rectangle { x: 35; y: 10; width: 60; height: 50; radius: 25; color: root.pigColor }
            Rectangle {
                x: 10; y: 14; width: 72; height: 64; radius: 32; color: root.pigColor
                Item { x: 20; y: 20; width: 14; height: 14; scale: root.eyeBlink; Rectangle { anchors.fill: parent; radius: 7; color: root.eyeColor; Rectangle { x: 2; y: 3; width: 4; height: 4; radius: 2; color: "#FFFFFF" } } }
                Rectangle { x: -6; y: 24; width: 28; height: 20; radius: 10; color: root.snoutColor; Rectangle { x: 6; y: 5; width: 4; height: 8; radius: 2; color: "#2B1B17" } }
            }
        }

        // 3. Right
        Item {
            visible: root.effectivePosition === "right"
            x: islandRoot.x + root.islandWidth - 24 + root.peekOffset; y: islandRoot.y - 12; width: 100; height: 90
            transform: Scale { xScale: -1; origin.x: 50 }
            Rectangle { x: 35; y: 10; width: 60; height: 50; radius: 25; color: root.pigColor }
            Rectangle {
                x: 10; y: 14; width: 72; height: 64; radius: 32; color: root.pigColor
                Item { x: 20; y: 20; width: 14; height: 14; scale: root.eyeBlink; Rectangle { anchors.fill: parent; radius: 7; color: root.eyeColor; Rectangle { x: 2; y: 3; width: 4; height: 4; radius: 2; color: "#FFFFFF" } } }
                Rectangle { x: -6; y: 24; width: 28; height: 20; radius: 10; color: root.snoutColor; Rectangle { x: 6; y: 5; width: 4; height: 8; radius: 2; color: "#2B1B17" } }
            }
        }

        // 4. Bottom-Left
        Item {
            visible: root.effectivePosition === "bottom-left"
            x: islandRoot.x - 28 - root.peekOffset * 0.7; y: islandRoot.y + root.islandHeight - 28 + root.peekOffset * 0.7; width: 110; height: 100; rotation: -18
            Rectangle { x: 20; y: 0; width: 70; height: 50; radius: 25; color: root.pigColor }
            Rectangle {
                x: 14; y: 12; width: 80; height: 70; radius: 35; color: root.pigColor
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 34; width: 34; height: 22; radius: 11; color: root.snoutColor }
            }
        }

        // 5. Bottom-Right
        Item {
            visible: root.effectivePosition === "bottom-right"
            x: islandRoot.x + root.islandWidth - 82 + root.peekOffset * 0.7; y: islandRoot.y + root.islandHeight - 28 + root.peekOffset * 0.7; width: 110; height: 100; rotation: 18
            Rectangle { x: 20; y: 0; width: 70; height: 50; radius: 25; color: root.pigColor }
            Rectangle {
                x: 14; y: 12; width: 80; height: 70; radius: 35; color: root.pigColor
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 34; width: 34; height: 22; radius: 11; color: root.snoutColor }
            }
        }
    }

    // =========================================================================
    // LAYER 2: CENTER ISLAND PILL
    // =========================================================================
    Rectangle {
        id: islandRoot
        anchors.horizontalCenter: parent.horizontalCenter
        y: 20
        width: root.islandWidth
        height: root.islandHeight
        radius: root.islandRadius
        color: "#08060D"
        border.color: "#231B34"
        border.width: 1.5
        clip: true

        // Ánh sáng viền trên
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 1
            width: parent.width - 40
            height: 1
            color: "#6D50A2"
            opacity: 0.6
        }

        // ---------------------------------------------------------------------
        // NỘI DUNG CHẾ ĐỘ "ROAM" (Tung tăng bên trong Center Island)
        // ---------------------------------------------------------------------
        Item {
            anchors.fill: parent
            visible: root.displayMode === "roam"

            // Header Status text ở góc phải
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.actionTitle
                    color: "#81E6D9"
                    font.pixelSize: 11
                    font.bold: true
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3; color: "#48BB78"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "12:00"
                    color: "#A0AEC0"
                    font.pixelSize: 11
                }
            }

            // CHÚ HEO THU NHỎ TUNG TĂNG DI CHUYỂN QUA LẠI
            Item {
                id: miniPigContainer
                x: root.pigX
                y: (islandRoot.height - 42) / 2 + root.jumpY
                width: 44
                height: 42

                // Hướng mặt: nếu đi sang trái thì lật ngang
                transform: Scale {
                    xScale: root.pigDir === -1 ? -1 : 1
                    origin.x: 22
                }

                // 1. Walking Mini
                Pig.WalkingPig {
                    anchors.centerIn: parent
                    scale: 0.22
                    visible: root.activeRoamAction === "walking"
                    pigColor: root.pigColor
                    paused: root.paused
                    viewAngle: "right"
                }

                // 2. Running Mini
                RunningPig {
                    anchors.centerIn: parent
                    scale: 0.22
                    visible: root.activeRoamAction === "running"
                    pigColor: root.pigColor
                    paused: root.paused
                    viewAngle: "right"
                }

                // 3. Coffee / Boba Mini
                Pig.CoffeePig {
                    anchors.centerIn: parent
                    scale: 0.22
                    visible: root.activeRoamAction === "coffee"
                    pigColor: root.pigColor
                    paused: root.paused
                    viewAngle: "front"
                }

                // 4. Coder Mini
                Pig.CoderPig {
                    anchors.centerIn: parent
                    scale: 0.22
                    visible: root.activeRoamAction === "coder"
                    pigColor: root.pigColor
                    paused: root.paused
                    viewAngle: "front"
                }

                // 5. Detective Mini
                DetectivePig {
                    anchors.centerIn: parent
                    scale: 0.22
                    visible: root.activeRoamAction === "detective"
                    pigColor: root.pigColor
                    paused: root.paused
                    viewAngle: "right"
                }

                // 6. Gym Mini
                GymPig {
                    anchors.centerIn: parent
                    scale: 0.22
                    visible: root.activeRoamAction === "gym"
                    pigColor: root.pigColor
                    paused: root.paused
                    viewAngle: "front"
                }

                // 7. Lying Back Mini
                LyingBackPig {
                    anchors.centerIn: parent
                    scale: 0.22
                    visible: root.activeRoamAction === "lying"
                    pigColor: root.pigColor
                    paused: root.paused
                    viewAngle: "front"
                }

                // 8. Sleepy Mini
                Pig.SleepyPig {
                    anchors.centerIn: parent
                    scale: 0.22
                    visible: root.activeRoamAction === "sleepy"
                    pigColor: root.pigColor
                    paused: root.paused
                    viewAngle: "front"
                }
            }
        }

        // NỘI DUNG KHI Ở CHẾ ĐỘ CLING (Mô phỏng Sensor thông thường)
        Row {
            anchors.centerIn: parent
            visible: root.displayMode === "cling"
            spacing: 12

            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 3.5; color: "#48BB78" }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Titonium Center Island"; color: "#E2E8F0"; font.pixelSize: 12; font.bold: true }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "12:00"; color: "#A0AEC0"; font.pixelSize: 11 }
        }
    }

    // =========================================================================
    // LAYER 3: CLINGING HOOVES (Móng bám khi ở chế độ Cling)
    // =========================================================================
    Item {
        id: hoovesLayer
        anchors.fill: parent
        visible: root.displayMode === "cling"

        Item {
            visible: root.effectivePosition === "bottom"
            anchors.horizontalCenter: parent.horizontalCenter
            y: islandRoot.y + root.islandHeight - 8 - root.hoofTension
            width: 100; height: 20

            Rectangle {
                x: 10; y: 0; width: 18; height: 16; radius: 8; color: root.pigColor; border.color: Qt.darker(root.pigColor, 1.1); border.width: 1
                Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 4; radius: 2; color: root.hoofColor }
            }
            Rectangle {
                x: 72; y: 0; width: 18; height: 16; radius: 8; color: root.pigColor; border.color: Qt.darker(root.pigColor, 1.1); border.width: 1
                Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 10; height: 4; radius: 2; color: root.hoofColor }
            }
        }

        Item {
            visible: root.effectivePosition === "left"
            x: islandRoot.x - 4 + root.hoofTension; y: islandRoot.y + 6; width: 20; height: 32
            Rectangle { x: 0; y: 2; width: 16; height: 14; radius: 7; color: root.pigColor }
            Rectangle { x: 0; y: 18; width: 16; height: 14; radius: 7; color: root.pigColor }
        }

        Item {
            visible: root.effectivePosition === "right"
            x: islandRoot.x + root.islandWidth - 12 - root.hoofTension; y: islandRoot.y + 6; width: 20; height: 32
            Rectangle { x: 0; y: 2; width: 16; height: 14; radius: 7; color: root.pigColor }
            Rectangle { x: 0; y: 18; width: 16; height: 14; radius: 7; color: root.pigColor }
        }

        Item {
            visible: root.effectivePosition === "bottom-left"
            x: islandRoot.x + 4; y: islandRoot.y + root.islandHeight - 16; width: 30; height: 24
            Rectangle { x: -6; y: -2; width: 16; height: 14; radius: 7; color: root.pigColor; rotation: -30 }
            Rectangle { x: 10; y: 4; width: 16; height: 14; radius: 7; color: root.pigColor; rotation: -10 }
        }

        Item {
            visible: root.effectivePosition === "bottom-right"
            x: islandRoot.x + root.islandWidth - 34; y: islandRoot.y + root.islandHeight - 16; width: 30; height: 24
            Rectangle { x: 4; y: 4; width: 16; height: 14; radius: 7; color: root.pigColor; rotation: 10 }
            Rectangle { x: 20; y: -2; width: 16; height: 14; radius: 7; color: root.pigColor; rotation: 30 }
        }
    }

    // Tương tác chuột
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.triggerScare()
    }
}
