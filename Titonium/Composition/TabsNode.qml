pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Design
import qs.Titonium.Design.Controls as Controls
import qs.Titonium.Foundation

Item {
    id: root

    required property var node
    required property var screen
    required property var context
    property alias currentIndex: tabsControl.currentIndex

    readonly property var tabs: root.node.pages || []
    readonly property var activeTab: root.tabs[root.currentIndex] || ({})
    readonly property var displayTabs: root.tabs.map(tab => ({
        label: tab.labelKey ? I18n.tr(tab.labelKey) : (tab.label || tab.id),
        value: tab.id
    }))

    implicitWidth: Math.max(tabsControl.implicitWidth, page.implicitWidth)
    implicitHeight: tabsControl.implicitHeight + Metrics.spacingXSmall + page.implicitHeight

    Controls.Tabs {
        id: tabsControl
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        model: root.displayTabs
        accessibleName: root.node.id
    }

    NodeHost {
        id: page
        anchors.top: tabsControl.bottom
        anchors.topMargin: Metrics.spacingXSmall
        anchors.horizontalCenter: parent.horizontalCenter
        node: root.activeTab.child || {
            "type": "spacer",
            "id": root.node.id + ".empty",
            "size": 0
        }
        screen: root.screen
        context: root.context
    }
}
