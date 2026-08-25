pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property date today: ClockModel.now
    property int displayedYear: root.today.getFullYear()
    property int displayedMonth: root.today.getMonth()
    readonly property var days: root.buildDays()

    function previousMonth(): void {
        const date = new Date(root.displayedYear, root.displayedMonth - 1, 1);
        root.displayedYear = date.getFullYear();
        root.displayedMonth = date.getMonth();
    }

    function nextMonth(): void {
        const date = new Date(root.displayedYear, root.displayedMonth + 1, 1);
        root.displayedYear = date.getFullYear();
        root.displayedMonth = date.getMonth();
    }

    function resetToday(): void {
        root.displayedYear = root.today.getFullYear();
        root.displayedMonth = root.today.getMonth();
    }

    function buildDays(): var {
        const first = new Date(root.displayedYear, root.displayedMonth, 1);
        const mondayOffset = (first.getDay() + 6) % 7;
        const start = new Date(root.displayedYear, root.displayedMonth, 1 - mondayOffset);
        const result = [];
        for (let index = 0; index < 42; index++) {
            const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + index);
            const lunar = LunarModel.forDate(date);
            result.push({
                "date": date,
                "day": date.getDate(),
                "currentMonth": date.getMonth() === root.displayedMonth,
                "today": date.getFullYear() === root.today.getFullYear()
                    && date.getMonth() === root.today.getMonth()
                    && date.getDate() === root.today.getDate(),
                "lunar": lunar
            });
        }
        return result;
    }
}
