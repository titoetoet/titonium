pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

WidgetBase {
    id: root

    implicitWidth: 52
    implicitHeight: Metrics.widgetHeight

    InputMethodModel { id: inputModel }

    Controls.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusSmall
        outlined: true
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Metrics.spacingXSmall

        Controls.Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "keyboard"
            size: 18
            tone: inputModel.shortLabel === "IM" ? "secondary" : "accent"
            accessibleName: ""
        }

        Controls.TextLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: inputModel.shortLabel
            variant: "label"
            strong: true
            tone: inputModel.shortLabel === "IM" ? "secondary" : "primary"
            Accessible.name: I18n.tr("menubar.input_method.accessible", {
                "name": inputModel.displayName
            })
        }
    }
}
