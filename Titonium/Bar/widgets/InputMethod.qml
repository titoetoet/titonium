pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.InputMethod
import qs.Titonium.Theme
import qs.Titonium.Shared as Shared

Item {
    id: root
    required property var screen
    implicitWidth: 52
    implicitHeight: Metrics.widgetHeight

    Row {
        anchors.centerIn: parent
        spacing: Metrics.spacingXSmall
        Shared.Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "keyboard"
            size: 18
            tone: InputMethodService.shortLabel === "IM" ? "secondary" : "accent"
            accessibleName: ""
        }
        Shared.TextLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: InputMethodService.shortLabel
            variant: "label"
            strong: true
            tone: InputMethodService.shortLabel === "IM" ? "secondary" : "primary"
            Accessible.name: I18n.tr("menubar.input_method.accessible", {
                name: InputMethodService.displayName
            })
        }
    }
}
