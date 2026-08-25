pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""
    readonly property date now: secondsClock.date
    readonly property real hourAngle: ((root.now.getHours() % 12)
        + root.now.getMinutes() / 60 + root.now.getSeconds() / 3600) * 30
    readonly property real minuteAngle: (root.now.getMinutes() + root.now.getSeconds() / 60) * 6
    readonly property real secondAngle: root.now.getSeconds() * 6
    readonly property string timezoneOffset: {
        const offsetMinutes = -root.now.getTimezoneOffset();
        const sign = offsetMinutes >= 0 ? "+" : "-";
        const absolute = Math.abs(offsetMinutes);
        const hours = Math.floor(absolute / 60);
        const minutes = absolute % 60;
        return "UTC" + sign + String(hours).padStart(2, "0")
            + ":" + String(minutes).padStart(2, "0");
    }

    anchors.fill: parent
    focus: true

    function close(): void { SurfaceCoordinator.close(root.ownerId); }

    function pointInside(item: Item, point: point): bool {
        const local = item.mapFromItem(root, point.x, point.y);
        return local.x >= 0 && local.y >= 0 && local.x <= item.width && local.y <= item.height;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
        TapHandler {
            onTapped: eventPoint => {
                if (!root.pointInside(panel, eventPoint.position)) root.close();
            }
        }
    }

    Controls.Panel {
        id: panel

        z: 1
        width: 320
        height: 390
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Metrics.barHeight + Metrics.spacingSmall
        anchors.rightMargin: Metrics.barPadding
        padding: Metrics.spacingLarge

        ColumnLayout {
            anchors.fill: parent
            spacing: Metrics.spacingMedium

            RowLayout {
                Layout.fillWidth: true

                Controls.TextLabel {
                    Layout.fillWidth: true
                    text: I18n.tr("clock.title")
                    variant: "title_small"
                    strong: true
                }

                Controls.Button {
                    iconName: "close"
                    variant: "quiet"
                    size: "small"
                    accessibleName: I18n.tr("clock.close")
                    onTriggered: root.close()
                }
            }

            Item {
                id: clockFace

                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 236
                Layout.preferredHeight: 236

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.surfaceElevated
                    border.width: Metrics.borderWidth
                    border.color: Theme.borderStrong
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 18
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Metrics.borderWidth
                    border.color: Theme.border
                }

                Repeater {
                    model: 60

                    Item {
                        id: tick
                        required property int index

                        anchors.fill: parent
                        rotation: tick.index * 6

                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: tick.index % 5 === 0 ? 9 : 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tick.index % 15 === 0 ? 3 : (tick.index % 5 === 0 ? 2 : 1)
                            height: tick.index % 15 === 0 ? 13 : (tick.index % 5 === 0 ? 9 : 4)
                            radius: width / 2
                            color: tick.index % 15 === 0
                                ? Theme.accent
                                : (tick.index % 5 === 0 ? Theme.textPrimary : Theme.textDisabled)
                        }
                    }
                }

                Controls.TextLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 58
                    text: "TITONIUM"
                    variant: "caption"
                    strong: true
                    font.letterSpacing: 2
                    tone: "secondary"
                }

                Item {
                    anchors.fill: parent
                    rotation: root.hourAngle

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.verticalCenter
                        width: 5
                        height: 58
                        radius: width / 2
                        color: Theme.textPrimary
                    }
                }

                Item {
                    anchors.fill: parent
                    rotation: root.minuteAngle

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.verticalCenter
                        width: 3
                        height: 82
                        radius: width / 2
                        color: Theme.textPrimary
                    }
                }

                Item {
                    anchors.fill: parent
                    rotation: root.secondAngle

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.verticalCenter
                        anchors.bottomMargin: -18
                        width: 1
                        height: 108
                        color: Theme.accent
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: width / 2
                    color: Theme.accent
                    border.width: 2
                    border.color: Theme.textPrimary
                }
            }

            Controls.TextLabel {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(root.now, "HH:mm:ss")
                variant: "title_large"
                strong: true
            }

            Controls.TextLabel {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(root.now, "dddd, dd MMMM yyyy")
                variant: "caption"
                tone: "secondary"
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Metrics.spacingSmall

                Controls.Icon {
                    name: "schedule"
                    size: 16
                    tone: "accent"
                    accessibleName: ""
                }
                Controls.TextLabel {
                    text: I18n.tr("clock.timezone") + " · " + root.timezoneOffset
                    variant: "caption"
                    tone: "secondary"
                }
            }
        }
    }

    SystemClock {
        id: secondsClock
        precision: SystemClock.Seconds
    }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
