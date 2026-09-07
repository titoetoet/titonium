pragma ComponentBehavior: Bound

import QtQuick
import "../../Titonium/Shared/Mascots/Pig" as Pig
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: window
    width: 1060
    height: 750
    minimumWidth: 880
    minimumHeight: 620
    visible: true
    title: "🐷 Piggy Mascot Suite — Titonium Hệ Thống Đa Góc Nhìn (Chính diện, 3/4, Lưng, Ôm Island, Tung Tăng Island)"
    color: "#0F0E17"

    property int currentTab: 0 // 0: Sleepy, 1: Coder, 2: Boba, 3: Detective, 4: Walking, 5: Running, 6: Gym, 7: Lying Back, 8: Grid
    property color selectedPigColor: "#FFB6C1"
    property bool isPaused: false
    property real displayScale: 1.25

    // =========================================================================
    // HỆ THỐNG GÓC NHÌN (PERSPECTIVES)
    // "front"        : Chính diện
    // "left"         : Nghiêng trái 3/4
    // "right"        : Nghiêng phải 3/4
    // "back"         : Góc lưng
    // "island_cling" : Ôm Center Island (Người ẩn sau, mặt & tay ló ra các góc viền)
    // "island_roam"  : TUNG TĂNG trong Center Island (Heo nhỏ lại, tung tăng đi dạo, chạy lon ton, random kết hợp các hành động)
    // =========================================================================
    property string currentViewAngle: "island_roam" // Mặc định mở ngay góc nhìn "Tung tăng trong Center Island"
    property bool autoRotate: false

    // Tùy chọn khi ở góc "island_cling"
    property string currentIslandPos: "bottom" // "bottom", "left", "right", "bottom-left", "bottom-right", "peekaboo"

    // Tùy chọn khi ở góc "island_roam"
    property string selectedRoamAction: "random" // "random" | "walking" | "running" | "coffee" | "coder" | "detective" | "gym" | "lying" | "sleepy"

    // 360 Auto-Rotate Timer
    readonly property var rotateCycle: ["front", "left", "back", "right", "island_cling", "island_roam"]
    Timer {
        interval: 2500
        running: window.autoRotate && !window.isPaused
        repeat: true
        onTriggered: {
            let idx = window.rotateCycle.indexOf(window.currentViewAngle);
            idx = (idx + 1) % window.rotateCycle.length;
            window.currentViewAngle = window.rotateCycle[idx];
        }
    }

    // Color theme options
    readonly property var colorThemes: [
        { name: "Classic Pink", color: "#FFB6C1" },
        { name: "Sakura Blossom", color: "#FFCCD5" },
        { name: "Golden Fortune", color: "#F6E05E" },
        { name: "Cyber Mint", color: "#81E6D9" },
        { name: "Lavender Dream", color: "#D6BCFA" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // 1. Top Header Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "🐷"
                font.pixelSize: 32
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: "Titonium Pig Mascot Suite — Hệ Thống 6 Góc Nhìn Độc Đáo"
                    color: "#FFFFFF"
                    font.pixelSize: 18
                    font.bold: true
                }
                Text {
                    text: "Chính diện • Nghiêng 3/4 Trái/Phải • Lưng • Ôm Center Island • Tung Tăng trong Center Island"
                    color: "#A0AEC0"
                    font.pixelSize: 12
                }
            }

            Item { Layout.fillWidth: true }

            // Theme Color Pickers
            Row {
                spacing: 8
                Repeater {
                    model: window.colorThemes
                    delegate: Rectangle {
                        id: colorBtn
                        required property var modelData
                        width: 24
                        height: 24
                        radius: 12
                        color: colorBtn.modelData.color
                        border.color: window.selectedPigColor === colorBtn.modelData.color ? "#FFFFFF" : "#4A5568"
                        border.width: window.selectedPigColor === colorBtn.modelData.color ? 2.5 : 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.selectedPigColor = colorBtn.modelData.color
                        }
                    }
                }
            }

            // Pause / Play Toggle
            Button {
                id: pauseBtn
                text: window.isPaused ? "▶ Tiếp tục" : "⏸ Tạm dừng"
                onClicked: window.isPaused = !window.isPaused
                background: Rectangle {
                    color: "#241B35"
                    radius: 8
                    border.color: "#3B2D54"
                }
                contentItem: Text {
                    text: pauseBtn.text
                    color: "#E2E8F0"
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // 2. Main Angle Selector Bar (THANH CHỌN TẤT CẢ GÓC NHÌN)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 10
            color: "#181428"
            border.color: "#30264E"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 6

                Text {
                    text: "🧭 GÓC NHÌN:"
                    color: "#A0AEC0"
                    font.pixelSize: 11
                    font.bold: true
                }

                // 6 Góc nhìn chính
                Row {
                    spacing: 6
                    readonly property var angleItems: [
                        { id: "front", label: "Chính diện", icon: "⏺️" },
                        { id: "left", label: "Nghiêng trái 3/4", icon: "↙️" },
                        { id: "right", label: "Nghiêng phải 3/4", icon: "↘️" },
                        { id: "back", label: "Góc lưng", icon: "🔄" },
                        { id: "island_cling", label: "Ôm Center Island", icon: "🤗" },
                        { id: "island_roam", label: "Tung tăng Island", icon: "🏃" }
                    ]

                    Repeater {
                        model: parent.angleItems
                        delegate: Rectangle {
                            id: angleBtn
                            required property var modelData
                            width: 122
                            height: 32
                            radius: 6
                            color: window.currentViewAngle === angleBtn.modelData.id
                                ? (angleBtn.modelData.id === "island_roam" ? "#2B6CB0" :
                                   angleBtn.modelData.id === "island_cling" ? "#319795" : "#7928CA")
                                : "#241B38"
                            border.color: window.currentViewAngle === angleBtn.modelData.id
                                ? (angleBtn.modelData.id === "island_roam" ? "#63B3ED" :
                                   angleBtn.modelData.id === "island_cling" ? "#4FD1C5" : "#B794F4")
                                : "#3F325E"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: angleBtn.modelData.icon; font.pixelSize: 11 }
                                Text {
                                    text: angleBtn.modelData.label
                                    color: window.currentViewAngle === angleBtn.modelData.id ? "#FFFFFF" : "#CBD5E0"
                                    font.pixelSize: 11
                                    font.bold: window.currentViewAngle === angleBtn.modelData.id
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    window.autoRotate = false;
                                    window.currentViewAngle = angleBtn.modelData.id;
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Auto Rotate Toggle
                Rectangle {
                    Layout.preferredWidth: 126
                    Layout.preferredHeight: 32
                    radius: 6
                    color: window.autoRotate ? "#38A169" : "#241B38"
                    border.color: window.autoRotate ? "#68D391" : "#3F325E"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: window.autoRotate ? "🌀" : "🔄"; font.pixelSize: 11 }
                        Text {
                            text: window.autoRotate ? "Đang tự xoay..." : "360° Tự xoay"
                            color: "#FFFFFF"
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.autoRotate = !window.autoRotate
                    }
                }
            }
        }

        // 2.2 Thanh phụ tùy chỉnh chuyên sâu khi ở góc nhìn Island
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 8
            visible: window.currentViewAngle === "island_roam" || window.currentViewAngle === "island_cling"
            color: window.currentViewAngle === "island_roam" ? "#141C2E" : "#132328"
            border.color: window.currentViewAngle === "island_roam" ? "#2B4365" : "#234E52"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8

                // Khi đang ở góc "island_roam" (Tung tăng):
                Row {
                    spacing: 4
                    visible: window.currentViewAngle === "island_roam"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🎲 HÀNH ĐỘNG TUNG TĂNG:"
                        color: "#63B3ED"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    readonly property var roamButtons: [
                        { id: "random", label: "🎲 Random tự đổi" },
                        { id: "walking", label: "🚶 Đi dạo" },
                        { id: "running", label: "🏃 Chạy lon ton" },
                        { id: "coffee", label: "🧋 Trà sữa" },
                        { id: "coder", label: "💻 Gõ code" },
                        { id: "detective", label: "🔍 Thám tử" },
                        { id: "gym", label: "🏋️ Tập gym" },
                        { id: "lying", label: "🛌 Nằm ngửa" },
                        { id: "sleepy", label: "😴 Ngủ" }
                    ]

                    Repeater {
                        model: parent.roamButtons
                        delegate: Rectangle {
                            id: rBtn
                            required property var modelData
                            width: 86
                            height: 24
                            radius: 4
                            color: window.selectedRoamAction === rBtn.modelData.id ? "#3182CE" : "#1A202C"
                            border.color: window.selectedRoamAction === rBtn.modelData.id ? "#63B3ED" : "#2D3748"

                            Text {
                                anchors.centerIn: parent
                                text: rBtn.modelData.label
                                color: window.selectedRoamAction === rBtn.modelData.id ? "#FFFFFF" : "#A0AEC0"
                                font.pixelSize: 10
                                font.bold: window.selectedRoamAction === rBtn.modelData.id
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.selectedRoamAction = rBtn.modelData.id
                            }
                        }
                    }
                }

                // Khi đang ở góc "island_cling" (Ôm viền):
                Row {
                    spacing: 4
                    visible: window.currentViewAngle === "island_cling"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "📍 VỊ TRÍ BÁM VIỀN:"
                        color: "#4FD1C5"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    readonly property var clingButtons: [
                        { id: "bottom", label: "⬇️ Ló mép dưới" },
                        { id: "left", label: "⬅️ Ló mép trái" },
                        { id: "right", label: "➡️ Ló mép phải" },
                        { id: "bottom-left", label: "↙️ Góc dưới-trái" },
                        { id: "bottom-right", label: "↘️ Góc dưới-phải" },
                        { id: "peekaboo", label: "👻 Thò thụt tự động" }
                    ]

                    Repeater {
                        model: parent.clingButtons
                        delegate: Rectangle {
                            id: cBtn
                            required property var modelData
                            width: 108
                            height: 24
                            radius: 4
                            color: window.currentIslandPos === cBtn.modelData.id ? "#319795" : "#1A202C"
                            border.color: window.currentIslandPos === cBtn.modelData.id ? "#4FD1C5" : "#2D3748"

                            Text {
                                anchors.centerIn: parent
                                text: cBtn.modelData.label
                                color: window.currentIslandPos === cBtn.modelData.id ? "#FFFFFF" : "#A0AEC0"
                                font.pixelSize: 10
                                font.bold: window.currentIslandPos === cBtn.modelData.id
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.currentIslandPos = cBtn.modelData.id
                            }
                        }
                    }
                }
            }
        }

        // 3. Tab Navigation Bar (Chọn Mascot để xem)
        Flow {
            Layout.fillWidth: true
            spacing: 6

            readonly property var tabs: [
                { icon: "😴", title: "Sleepy" },
                { icon: "💻", title: "Coder" },
                { icon: "🧋", title: "Boba Chill" },
                { icon: "🔍", title: "Detective" },
                { icon: "🚶", title: "Đi bộ" },
                { icon: "🏃", title: "Chạy bộ" },
                { icon: "🏋️", title: "Tập gym" },
                { icon: "🛌", title: "Nằm ngửa" },
                { icon: "🌟", title: "Lưới Tất Cả" }
            ]

            Repeater {
                model: parent.tabs
                delegate: Rectangle {
                    id: tabBtn
                    required property var modelData
                    required property int index

                    width: 106
                    height: 36
                    radius: 8
                    color: window.currentTab === tabBtn.index ? "#7928CA" : "#1A162B"
                    border.color: window.currentTab === tabBtn.index ? "#B794F4" : "#2E2648"
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: tabBtn.modelData.icon; font.pixelSize: 14 }
                        Text {
                            text: tabBtn.modelData.title
                            color: window.currentTab === tabBtn.index ? "#FFFFFF" : "#CBD5E0"
                            font.bold: window.currentTab === tabBtn.index
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.currentTab = tabBtn.index
                    }
                }
            }
        }

        // 4. Main Stage Content Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: "#161324"
            border.color: "#282142"
            border.width: 1
            clip: true

            // Instruction label
            Text {
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                z: 10
                text: {
                    if (window.currentViewAngle === "island_roam") {
                        return "🏃 GÓC NHÌN: TUNG TĂNG TRONG CENTER ISLAND (Heo nhỏ lại, tung tăng đi dạo, chạy lon ton, đổi random hành động!)";
                    } else if (window.currentViewAngle === "island_cling") {
                        return "🤗 GÓC NHÌN: ÔM CENTER ISLAND (Người ẩn sau khối đen, mặt và hai móng bám chặt lấy viền pill!)";
                    } else {
                        return "✨ GÓC NHÌN: " +
                            (window.currentViewAngle === "front" ? "CHÍNH DIỆN" :
                             window.currentViewAngle === "left" ? "NGHIÊNG TRÁI 3/4" :
                             window.currentViewAngle === "right" ? "NGHIÊNG PHẢI 3/4" : "GÓC LƯNG") +
                            " (Bấm chuột vào chú heo để tương tác emote!)";
                    }
                }
                color: window.currentViewAngle === "island_roam" ? "#63B3ED" :
                       window.currentViewAngle === "island_cling" ? "#4FD1C5" : "#A0AEC0"
                font.pixelSize: 12
                font.bold: true
            }

            // A. Single View (Tabs 0 to 7)
            Item {
                anchors.fill: parent
                visible: window.currentTab < 8

                // A.1 HIỂN THỊ KHI Ở GÓC NHÌN "island_roam" HOẶC "island_cling"
                IslandPig {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 35
                    scale: window.displayScale
                    visible: window.currentViewAngle === "island_roam" || window.currentViewAngle === "island_cling"
                    pigColor: window.selectedPigColor
                    paused: window.isPaused
                    displayMode: window.currentViewAngle === "island_roam" ? "roam" : "cling"
                    roamAction: window.selectedRoamAction
                    islandPosition: window.currentIslandPos
                }

                // A.2 HIỂN THỊ CÁC MASCOT RIÊNG LẺ (KHI Ở 4 GÓC NHÌN THÔNG THƯỜNG: front, left, right, back)
                Item {
                    anchors.fill: parent
                    visible: window.currentViewAngle !== "island_roam" && window.currentViewAngle !== "island_cling"

                    // 0. Sleepy Pig
                    Pig.SleepyPig {
                        anchors.centerIn: parent
                        scale: window.displayScale
                        visible: window.currentTab === 0
                        pigColor: window.selectedPigColor
                        paused: window.isPaused
                        viewAngle: window.currentViewAngle
                    }

                    // 1. Coder Pig
                    Pig.CoderPig {
                        anchors.centerIn: parent
                        scale: window.displayScale
                        visible: window.currentTab === 1
                        pigColor: window.selectedPigColor
                        paused: window.isPaused
                        viewAngle: window.currentViewAngle
                    }

                    // 2. Coffee Pig
                    Pig.CoffeePig {
                        anchors.centerIn: parent
                        scale: window.displayScale
                        visible: window.currentTab === 2
                        pigColor: window.selectedPigColor
                        paused: window.isPaused
                        viewAngle: window.currentViewAngle
                    }

                    // 3. Detective Pig
                    DetectivePig {
                        anchors.centerIn: parent
                        scale: window.displayScale
                        visible: window.currentTab === 3
                        pigColor: window.selectedPigColor
                        paused: window.isPaused
                        viewAngle: window.currentViewAngle
                    }

                    // 4. Walking Pig
                    Pig.WalkingPig {
                        anchors.centerIn: parent
                        scale: window.displayScale
                        visible: window.currentTab === 4
                        pigColor: window.selectedPigColor
                        paused: window.isPaused
                        viewAngle: window.currentViewAngle
                    }

                    // 5. Running Pig
                    RunningPig {
                        anchors.centerIn: parent
                        scale: window.displayScale
                        visible: window.currentTab === 5
                        pigColor: window.selectedPigColor
                        paused: window.isPaused
                        viewAngle: window.currentViewAngle
                    }

                    // 6. Gym Pig
                    GymPig {
                        anchors.centerIn: parent
                        scale: window.displayScale
                        visible: window.currentTab === 6
                        pigColor: window.selectedPigColor
                        paused: window.isPaused
                        viewAngle: window.currentViewAngle
                    }

                    // 7. Lying Back Pig
                    LyingBackPig {
                        anchors.centerIn: parent
                        scale: window.displayScale
                        visible: window.currentTab === 7
                        pigColor: window.selectedPigColor
                        paused: window.isPaused
                        viewAngle: window.currentViewAngle
                    }
                }
            }

            // B. Grid View (Tab 8: Xem toàn bộ)
            ScrollView {
                anchors.fill: parent
                visible: window.currentTab === 8
                clip: true

                GridLayout {
                    width: parent.width - 20
                    columns: 4
                    rowSpacing: 10
                    columnSpacing: 10
                    anchors.margins: 10

                    // 1. Sleepy
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 12
                        color: "#1E1A31"
                        border.color: "#352A54"
                        Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "😴 Sleepy"; color: "#A0AEC0"; font.bold: true; font.pixelSize: 10 }
                        Pig.SleepyPig { anchors.centerIn: parent; scale: 0.6; pigColor: window.selectedPigColor; paused: window.isPaused; viewAngle: window.currentViewAngle }
                    }

                    // 2. Coder
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 12
                        color: "#1E1A31"
                        border.color: "#352A54"
                        Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "💻 Coder"; color: "#A0AEC0"; font.bold: true; font.pixelSize: 10 }
                        Pig.CoderPig { anchors.centerIn: parent; scale: 0.6; pigColor: window.selectedPigColor; paused: window.isPaused; viewAngle: window.currentViewAngle }
                    }

                    // 3. Boba
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 12
                        color: "#1E1A31"
                        border.color: "#352A54"
                        Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "🧋 Boba"; color: "#A0AEC0"; font.bold: true; font.pixelSize: 10 }
                        Pig.CoffeePig { anchors.centerIn: parent; scale: 0.6; pigColor: window.selectedPigColor; paused: window.isPaused; viewAngle: window.currentViewAngle }
                    }

                    // 4. Detective
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 12
                        color: "#1E1A31"
                        border.color: "#352A54"
                        Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "🔍 Detective"; color: "#A0AEC0"; font.bold: true; font.pixelSize: 10 }
                        DetectivePig { anchors.centerIn: parent; scale: 0.6; pigColor: window.selectedPigColor; paused: window.isPaused; viewAngle: window.currentViewAngle }
                    }

                    // 5. Walking
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 12
                        color: "#1E1A31"
                        border.color: "#352A54"
                        Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "🚶 Đi bộ"; color: "#A0AEC0"; font.bold: true; font.pixelSize: 10 }
                        Pig.WalkingPig { anchors.centerIn: parent; scale: 0.6; pigColor: window.selectedPigColor; paused: window.isPaused; viewAngle: window.currentViewAngle }
                    }

                    // 6. Running
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 12
                        color: "#1E1A31"
                        border.color: "#352A54"
                        Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "🏃 Chạy bộ"; color: "#A0AEC0"; font.bold: true; font.pixelSize: 10 }
                        RunningPig { anchors.centerIn: parent; scale: 0.6; pigColor: window.selectedPigColor; paused: window.isPaused; viewAngle: window.currentViewAngle }
                    }

                    // 7. Gym
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 12
                        color: "#1E1A31"
                        border.color: "#352A54"
                        Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "🏋️ Gym"; color: "#A0AEC0"; font.bold: true; font.pixelSize: 10 }
                        GymPig { anchors.centerIn: parent; scale: 0.6; pigColor: window.selectedPigColor; paused: window.isPaused; viewAngle: window.currentViewAngle }
                    }

                    // 8. Lying Back
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        radius: 12
                        color: "#1E1A31"
                        border.color: "#352A54"
                        Text { anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6; text: "🛌 Nằm ngửa"; color: "#A0AEC0"; font.bold: true; font.pixelSize: 10 }
                        LyingBackPig { anchors.centerIn: parent; scale: 0.6; pigColor: window.selectedPigColor; paused: window.isPaused; viewAngle: window.currentViewAngle }
                    }
                }
            }
        }
    }
}
