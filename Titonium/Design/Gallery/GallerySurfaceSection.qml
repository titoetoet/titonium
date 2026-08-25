pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Column {
    id: root

    spacing: Metrics.spacingSmall

    Controls.TextLabel {
        text: I18n.tr("gallery.surfaces")
        variant: "label"
        strong: true
    }

    Row {
        spacing: Metrics.spacingSmall

        Controls.Surface {
            width: 200
            height: 88
            padding: Metrics.spacingMedium

            Column {
                spacing: Metrics.spacingXSmall
                Controls.TextLabel { text: I18n.tr("gallery.surface.title"); variant: "label"; strong: true }
                Controls.TextLabel { text: I18n.tr("gallery.surface.detail"); variant: "caption"; tone: "secondary" }
            }
        }

        Controls.Card {
            width: 240
            height: 88
            interactive: true
            accessibleName: I18n.tr("gallery.card.accessible")

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Metrics.spacingSmall
                Controls.Icon { name: "widgets"; tone: "accent" }
                Column {
                    spacing: Metrics.spacingXSmall
                    Controls.TextLabel { text: I18n.tr("gallery.card.title"); variant: "label"; strong: true }
                    Controls.TextLabel { text: I18n.tr("gallery.card.detail"); variant: "caption"; tone: "secondary" }
                }
            }
        }

        Controls.Panel {
            width: 360
            height: 112
            padding: Metrics.spacingMedium

            Column {
                width: parent.width
                spacing: Metrics.spacingSmall

                Controls.TextLabel { text: I18n.tr("gallery.panel.title"); variant: "titleSmall" }
                Controls.Card {
                    width: parent.width
                    height: 52
                    padding: Metrics.spacingSmall
                    outlined: false
                    Controls.TextLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("gallery.panel.detail")
                        variant: "caption"
                        tone: "secondary"
                    }
                }
            }
        }
    }
}
