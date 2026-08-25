pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Column {
    id: root

    spacing: Metrics.spacingSmall

    Controls.TextLabel {
        text: I18n.tr("gallery.tabs")
        variant: "label"
        strong: true
    }

    Row {
        spacing: Metrics.spacingLarge

        Controls.Tabs {
            id: sampleTabs
            width: 420
            model: [
                { label: I18n.tr("gallery.tabs.overview"), icon: "dashboard", value: "overview" },
                { label: I18n.tr("gallery.tabs.appearance"), icon: "palette", value: "appearance" },
                { label: I18n.tr("gallery.tabs.accessibility"), icon: "accessibility_new", value: "accessibility" }
            ]
            accessibleName: I18n.tr("gallery.tabs.accessible")
        }

        Controls.Card {
            width: 360
            height: sampleTabs.implicitHeight
            padding: Metrics.spacingSmall
            tone: "base"

            Row {
                anchors.fill: parent
                spacing: Metrics.spacingSmall

                Controls.Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: sampleTabs.currentIndex === 0 ? "dashboard"
                        : sampleTabs.currentIndex === 1 ? "palette"
                        : "accessibility_new"
                    tone: "accent"
                    accessibleName: ""
                }

                Controls.TextLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: sampleTabs.currentIndex === 0 ? I18n.tr("gallery.tabs.overview.detail")
                        : sampleTabs.currentIndex === 1 ? I18n.tr("gallery.tabs.appearance.detail")
                        : I18n.tr("gallery.tabs.accessibility.detail")
                    variant: "caption"
                    tone: "secondary"
                }
            }
        }
    }
}
