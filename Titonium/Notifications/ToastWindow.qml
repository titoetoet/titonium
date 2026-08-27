pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Titonium.Services.Notifications
import qs.Titonium.Theme

PanelWindow {
    id: window
    required property ShellScreen screenModel
    readonly property real panelTop: Metrics.barHeight + Metrics.barSpacing
    readonly property int toastCount: NotificationService.toastNotifications.length
    readonly property real stackHeight: window.toastCount * 120
        + Math.max(0, window.toastCount - 1) * Metrics.spacingSmall

    screen: window.screenModel
    visible: NotificationService.toastNotifications.length > 0
    color: "transparent"
    implicitWidth: 360 + Metrics.barPadding * 2
    implicitHeight: window.panelTop + window.stackHeight + Metrics.barPadding
    aboveWindows: true
    exclusiveZone: 0
    WlrLayershell.namespace: "titonium-notification-toast"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; right: true; left: false; bottom: false }
    mask: Region {
        Region { item: stackLoader }
    }

    Loader {
        id: stackLoader
        width: 360
        height: window.stackHeight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: window.panelTop
        anchors.rightMargin: Metrics.barPadding
        active: NotificationService.toastNotifications.length > 0
        sourceComponent: ToastStack {
            screenModel: window.screenModel
        }
    }
}
