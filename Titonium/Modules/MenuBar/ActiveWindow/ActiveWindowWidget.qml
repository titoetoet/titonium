pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Composition
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

WidgetBase {
    id: root

    readonly property int maximumWidth: Math.max(120, Number(root.node.props?.maximumWidth || 280))

    implicitWidth: Math.min(root.maximumWidth, contentRow.implicitWidth + Metrics.spacingSmall * 2)
    implicitHeight: Metrics.widgetHeight

    ActiveWindowModel { id: windowModel }

    Controls.Surface {
        anchors.fill: parent
        tone: "elevated"
        radius: Metrics.radiusSmall
        outlined: true
        clipContent: true
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Metrics.spacingSmall

        Controls.Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: windowModel.valid ? "web_asset" : "desktop_windows"
            size: 18
            tone: windowModel.valid ? "accent" : "secondary"
            accessibleName: ""
        }

        Controls.TextLabel {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maximumWidth - Metrics.spacingSmall * 3 - 18)
            text: windowModel.title
            variant: "label"
            tone: windowModel.valid ? "primary" : "secondary"
            elide: Text.ElideRight
            Accessible.name: I18n.tr("menubar.active_window.accessible", {
                "title": windowModel.title
            })
        }
    }
}
