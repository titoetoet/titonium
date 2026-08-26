pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Titonium.Core.Runtime
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen
    implicitWidth: clockButton.implicitWidth
    implicitHeight: Metrics.widgetHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Shared.Button {
        id: clockButton
        anchors.fill: parent
        label: Qt.formatDateTime(clock.date, Preferences.use24Hour ? "HH:mm" : "h:mm AP")
        iconName: "schedule"
        variant: "quiet"
        size: "small"
        accessibleName: I18n.tr("menubar.clock.accessible")
    }
}
