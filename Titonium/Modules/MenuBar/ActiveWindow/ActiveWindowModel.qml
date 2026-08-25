pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation
import qs.Titonium.Platform.Hyprland

QtObject {
    readonly property bool valid: HyprlandAdapter.activeWindowValid
    readonly property string title: valid && HyprlandAdapter.activeWindowTitle.length > 0
        ? HyprlandAdapter.activeWindowTitle
        : I18n.tr("menubar.active_window.desktop")
    readonly property string appClass: HyprlandAdapter.activeWindowClass
}
