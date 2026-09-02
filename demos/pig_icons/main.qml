pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: window
    width: 720
    height: 560
    visible: true
    title: "🐷 Piggy Animated Icons — Titonium Mascot Suite"
    color: "#13111C"

    property real globalIconSize: 96

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // Header Title
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "🐷"
                font.pixelSize: 28
            }

            ColumnLayout {
                spacing: 2
                Text {
                    text: "Titonium Pig Mascot Icons Suite"
                    color: "#FFFFFF"
                    font.pixelSize: 17
                    font.bold: true
                }
                Text {
                    text: "Bộ 4 biểu tượng hoạt họa Focus, Bell, Clipboard & AI Permission"
                    color: "#A0AEC0"
                    font.pixelSize: 12
                }
            }

            Item { Layout.fillWidth: true }

            // Global Size Switcher Buttons
            Row {
                spacing: 6
                Button {
                    id: btnSmall
                    text: "36px"
                    checked: window.globalIconSize === 36
                    onClicked: window.globalIconSize = 36
                    background: Rectangle {
                        color: btnSmall.checked ? "#7928CA" : "#241B35"
                        radius: 8
                        border.color: btnSmall.checked ? "#B794F4" : "#3B2D54"
                        border.width: 1
                    }
                    contentItem: Text { text: btnSmall.text; color: "#FFFFFF"; font.pixelSize: 11 }
                }
                Button {
                    id: btnMed
                    text: "72px"
                    checked: window.globalIconSize === 72
                    onClicked: window.globalIconSize = 72
                    background: Rectangle {
                        color: btnMed.checked ? "#7928CA" : "#241B35"
                        radius: 8
                        border.color: btnMed.checked ? "#B794F4" : "#3B2D54"
                        border.width: 1
                    }
                    contentItem: Text { text: btnMed.text; color: "#FFFFFF"; font.pixelSize: 11 }
                }
                Button {
                    id: btnLarge
                    text: "96px"
                    checked: window.globalIconSize === 96
                    onClicked: window.globalIconSize = 96
                    background: Rectangle {
                        color: btnLarge.checked ? "#7928CA" : "#241B35"
                        radius: 8
                        border.color: btnLarge.checked ? "#B794F4" : "#3B2D54"
                        border.width: 1
                    }
                    contentItem: Text { text: btnLarge.text; color: "#FFFFFF"; font.pixelSize: 11 }
                }
            }
        }

        // 2x2 Grid of Mascot Cards
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 14
            columnSpacing: 14

            // CARD 1: Focus Icon
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: "#1C1828"
                border.width: 1
                border.color: "#2E2544"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Text { text: "🎯 Focus Mode"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: focusIcon.active ? "● Đang thiền" : "○ Tạm dừng"
                            color: focusIcon.active ? "#00F2FE" : "#718096"
                            font.pixelSize: 11
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        PigFocusIcon {
                            id: focusIcon
                            anchors.centerIn: parent
                            width: window.globalIconSize
                            height: window.globalIconSize
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Button {
                            id: btnToggleFocus
                            text: focusIcon.active ? "Tạm nghỉ" : "Bật Focus"
                            Layout.fillWidth: true
                            onClicked: focusIcon.active = !focusIcon.active
                            background: Rectangle { color: "#2E2348"; radius: 8 }
                            contentItem: Text { text: btnToggleFocus.text; color: "#E2E8F0"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }
            }

            // CARD 2: Notification Bell Icon
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: "#1C1828"
                border.width: 1
                border.color: "#2E2544"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Text { text: "🔔 Notification Bell"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: bellIcon.unreadCount + " chưa đọc"
                            color: bellIcon.unreadCount > 0 ? "#ECC94B" : "#718096"
                            font.pixelSize: 11
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        PigBellIcon {
                            id: bellIcon
                            anchors.centerIn: parent
                            width: window.globalIconSize
                            height: window.globalIconSize
                            unreadCount: 3
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Button {
                            id: btnRing
                            text: "🔔 Rung chuông"
                            Layout.fillWidth: true
                            onClicked: bellIcon.ring()
                            background: Rectangle { color: "#2E2348"; radius: 8 }
                            contentItem: Text { text: btnRing.text; color: "#E2E8F0"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                        }
                        Button {
                            id: btnAddNotif
                            text: "+1 Tin"
                            onClicked: bellIcon.unreadCount += 1
                            background: Rectangle { color: "#2E2348"; radius: 8 }
                            contentItem: Text { text: btnAddNotif.text; color: "#E2E8F0"; font.pixelSize: 11 }
                        }
                    }
                }
            }

            // CARD 3: Clipboard Copy/Paste
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: "#1C1828"
                border.width: 1
                border.color: "#2E2544"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Text { text: "📋 Clipboard Copy"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: clipIcon.isCopied ? "Đã đóng dấu!" : "Sẵn sàng"
                            color: clipIcon.isCopied ? "#48BB78" : "#718096"
                            font.pixelSize: 11
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        PigClipboardIcon {
                            id: clipIcon
                            anchors.centerIn: parent
                            width: window.globalIconSize
                            height: window.globalIconSize
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Button {
                            id: btnCopy
                            text: "📋 Đóng dấu Copy"
                            Layout.fillWidth: true
                            onClicked: clipIcon.triggerCopy()
                            background: Rectangle { color: "#2E2348"; radius: 8 }
                            contentItem: Text { text: btnCopy.text; color: "#E2E8F0"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                        }
                        Button {
                            id: btnResetClip
                            text: "Làm mới"
                            onClicked: clipIcon.isCopied = false
                            background: Rectangle { color: "#2E2348"; radius: 8 }
                            contentItem: Text { text: btnResetClip.text; color: "#E2E8F0"; font.pixelSize: 11 }
                        }
                    }
                }
            }

            // CARD 4: AI Permission Request
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: "#1C1828"
                border.width: 1
                border.color: "#2E2544"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    RowLayout {
                        Text { text: "🛡️ AI Permission"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: {
                                if (aiIcon.status === "granted") return "✓ Cho phép";
                                if (aiIcon.status === "denied") return "✕ Từ chối";
                                return "⚡ Chờ duyệt...";
                            }
                            color: {
                                if (aiIcon.status === "granted") return "#48BB78";
                                if (aiIcon.status === "denied") return "#E53E3E";
                                return "#ED8936";
                            }
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        PigAiPermissionIcon {
                            id: aiIcon
                            anchors.centerIn: parent
                            width: window.globalIconSize
                            height: window.globalIconSize
                        }
                    }

                    RowLayout {
                        spacing: 6
                        Button {
                            id: btnAllow
                            text: "Cho phép"
                            Layout.fillWidth: true
                            onClicked: aiIcon.approve()
                            background: Rectangle { color: "#22543D"; radius: 8 }
                            contentItem: Text { text: btnAllow.text; color: "#9AE6B4"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                        }
                        Button {
                            id: btnDeny
                            text: "Từ chối"
                            Layout.fillWidth: true
                            onClicked: aiIcon.deny()
                            background: Rectangle { color: "#742A2A"; radius: 8 }
                            contentItem: Text { text: btnDeny.text; color: "#FEB2B2"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                        }
                        Button {
                            id: btnResetAi
                            text: "Yêu cầu"
                            onClicked: aiIcon.request()
                            background: Rectangle { color: "#2E2348"; radius: 8 }
                            contentItem: Text { text: btnResetAi.text; color: "#E2E8F0"; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }
    }
}
