pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Item {
    id: root

    implicitWidth: Metrics.controlHeightSmall
    implicitHeight: Metrics.widgetHeight

    Shared.Button {
        anchors.centerIn: parent
        width: Metrics.controlHeightSmall
        height: Metrics.controlHeightSmall
        iconName: BarVisibilityState.pinned ? "keep" : "keep_off"
        iconHoverMotion: true
        backgroundVisible: false
        variant: "quiet"
        size: "small"
        iconColor: BarVisibilityState.pinned ? Theme.accent : Theme.textPrimary
        showFocusRing: false
        backgroundRadius: Metrics.radiusLarge
        accessibleName: I18n.tr(BarVisibilityState.pinned
            ? "menubar.bar_pin.autohide" : "menubar.bar_pin.pin")
        onTriggered: BarVisibilityState.togglePinned()
    }
}
