pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

FocusScope {
    id: root

    property var descriptor: ({})
    property var screen: null
    readonly property string ownerId: root.descriptor?.ownerId || ""

    anchors.fill: parent
    focus: true

    function close(): void {
        SurfaceCoordinator.close(root.ownerId);
    }

    function monthTitle(): string {
        return I18n.tr("calendar.month." + (calendar.displayedMonth + 1))
            + " " + calendar.displayedYear;
    }

    function lunarText(lunar: var): string {
        return I18n.tr("calendar.lunar_today", {
            "day": lunar.day,
            "month": lunar.month,
            "year": lunar.yearName,
            "leap": lunar.leap ? " " + I18n.tr("calendar.leap") : ""
        });
    }

    function dateTitle(date: date): string {
        const weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        return I18n.tr("calendar.weekday_long." + weekdays[date.getDay()])
            + ", " + Qt.formatDate(date, "dd/MM/yyyy");
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.28)

        TapHandler { onTapped: root.close() }
    }

    Controls.Panel {
        id: panel
        z: 1
        width: 392
        height: 474
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Controls.TextLabel {
                        text: I18n.tr("calendar.title")
                        variant: "title"
                        strong: true
                    }

                    Controls.TextLabel {
                        text: root.dateTitle(calendar.today)
                        variant: "caption"
                        tone: "secondary"
                    }
                }

                Controls.Button {
                    iconName: "close"
                    variant: "quiet"
                    size: "small"
                    accessibleName: I18n.tr("calendar.close")
                    onTriggered: root.close()
                }
            }

            Controls.Surface {
                Layout.fillWidth: true
                implicitWidth: 1
                implicitHeight: 54
                tone: "elevated"
                radius: Metrics.radiusMedium
                outlined: true

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    Controls.TextLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.lunarText(LunarModel.forDate(calendar.today))
                        variant: "body"
                        strong: true
                    }

                    Controls.TextLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("calendar.lunar_caption")
                        variant: "caption"
                        tone: "secondary"
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Controls.Button {
                    iconName: "chevron_left"
                    variant: "quiet"
                    size: "small"
                    accessibleName: I18n.tr("calendar.previous_month")
                    onTriggered: calendar.previousMonth()
                }

                Controls.TextLabel {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.monthTitle()
                    variant: "title_small"
                    strong: true
                }

                Controls.Button {
                    iconName: "chevron_right"
                    variant: "quiet"
                    size: "small"
                    accessibleName: I18n.tr("calendar.next_month")
                    onTriggered: calendar.nextMonth()
                }
            }

            Grid {
                id: weekdayGrid
                Layout.alignment: Qt.AlignHCenter
                columns: 7
                columnSpacing: Metrics.spacingXSmall

                Repeater {
                    model: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

                    Controls.TextLabel {
                        required property string modelData
                        width: 46
                        height: 20
                        horizontalAlignment: Text.AlignHCenter
                        text: I18n.tr("calendar.weekday." + modelData)
                        variant: "caption"
                        tone: "secondary"
                        strong: true
                    }
                }
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 7
                columnSpacing: Metrics.spacingXSmall
                rowSpacing: Metrics.spacingXSmall

                Repeater {
                    model: 42

                    Rectangle {
                        id: dayCell
                        required property int index
                        readonly property var dayInfo: calendar.days[index]
                        width: 46
                        height: 42
                        radius: Metrics.radiusSmall
                        color: dayInfo.today ? Theme.accent : "transparent"
                        border.width: dayInfo.today ? 0 : Metrics.borderWidth
                        border.color: dayInfo.currentMonth ? Theme.border : "transparent"
                        opacity: dayInfo.currentMonth ? 1.0 : 0.45

                        Controls.TextLabel {
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCell.dayInfo.day
                            variant: "body"
                            strong: dayCell.dayInfo.today
                            color: dayCell.dayInfo.today ? Theme.accentText : Theme.textPrimary
                        }

                        Controls.TextLabel {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayCell.dayInfo.lunar.day === 1
                                ? dayCell.dayInfo.lunar.day + "/" + dayCell.dayInfo.lunar.month
                                : dayCell.dayInfo.lunar.day
                            variant: "caption"
                            color: dayCell.dayInfo.today ? Theme.accentText : Theme.textSecondary
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Controls.Button {
                Layout.alignment: Qt.AlignHCenter
                label: I18n.tr("calendar.today")
                variant: "secondary"
                size: "small"
                onTriggered: calendar.resetToday()
            }
        }
    }

    CalendarModel { id: calendar }

    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Component.onCompleted: root.forceActiveFocus(Qt.PopupFocusReason)
}
