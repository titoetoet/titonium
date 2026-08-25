pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    readonly property date now: systemClock.date

    function timeText(use24Hour: bool): string {
        return Qt.formatTime(systemClock.date, use24Hour ? "HH:mm" : "h:mm AP");
    }

    property SystemClock systemClock: SystemClock {
        precision: SystemClock.Minutes
    }
}
