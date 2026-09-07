pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    required property var snapshot
    required property var viewState
    signal intentRequested(var intent)
    readonly property var tabs: ["dashboard", "tasks", "monitoring", "wallpapers"]
    readonly property string selectedTab: root.tabs.indexOf(root.viewState?.expandedTab) >= 0
        ? root.viewState.expandedTab : "dashboard"
    implicitWidth: 760
    implicitHeight: 480

    function selectTab(index: int): void {
        const next = (index + root.tabs.length) % root.tabs.length;
        tabRepeater.itemAt(next).forceActiveFocus(Qt.TabFocusReason);
        root.intentRequested({type: "select-tab", tab: root.tabs[next]});
    }
    function revealTab(item: Item): void {
        const left = item.x;
        const right = left + item.width;
        const desired = left < tabScroll.contentX ? left
            : right > tabScroll.contentX + tabScroll.width ? right - tabScroll.width : tabScroll.contentX;
        tabScroll.contentX = Math.max(0, Math.min(desired, tabScroll.contentWidth - tabScroll.width));
    }
    function focusContent(): void {
        if (body.loadedItem) {
            body.loadedItem.forceActiveFocus(Qt.TabFocusReason);
            const next = body.loadedItem.nextItemInFocusChain(true);
            let ancestor = next;
            while (ancestor && ancestor !== body.loadedItem)
                ancestor = ancestor.parent;
            if (ancestor && next)
                next.forceActiveFocus(Qt.TabFocusReason);
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Metrics.spacingSmall
            Layout.rightMargin: Metrics.spacingSmall
            spacing: 0
            Flickable {
                id: tabScroll
                objectName: "expandedTabScroll"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredHeight: 48
                contentWidth: tabRow.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Row {
                    id: tabRow
                    Repeater {
                        id: tabRepeater
                        model: root.tabs
                        Shared.Button {
                            required property string modelData
                            required property int index
                            objectName: "expandedTab_" + modelData
                            label: I18n.tr("center.expanded.tab." + modelData)
                            variant: "quiet"
                            backgroundVisible: false
                            opacity: selected || hovered || activeFocus ? 1 : 0.65
                            backgroundRadius: Metrics.radiusSmall
                            selected: root.selectedTab === modelData
                            activeFocusOnTab: selected
                            focus: selected
                            height: 48
                            onActiveFocusChanged: if (activeFocus) root.revealTab(this)
                            onSelectedChanged: if (selected) Qt.callLater(() => root.revealTab(this))
                            Accessible.role: Accessible.PageTab
                            onTriggered: root.intentRequested({type: "select-tab", tab: modelData})
                            Keys.onLeftPressed: root.selectTab(index - 1)
                            Keys.onRightPressed: root.selectTab(index + 1)
                            Keys.onTabPressed: root.focusContent()
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: Metrics.radiusSmall
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.focus
                                visible: parent.activeFocus
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Metrics.spacingSmall
                                anchors.bottomMargin: 0
                                height: 2
                                visible: parent.selected
                                color: Theme.accent
                            }
                        }
                    }
                }
            }
            Shared.Button {
                id: closeButton
                objectName: "expandedClose"
                iconName: "close"
                variant: "quiet"
                accessibleName: I18n.tr("center.expanded.close")
                onTriggered: root.intentRequested({type: "request-mode", mode: "compact"})
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
        Controls.ScrollView {
            id: scroll
            implicitWidth: 0
            implicitHeight: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            contentHeight: body.height
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            Loader {
                id: body
                objectName: "expandedBody"
                readonly property Item loadedItem: item as Item
                width: scroll.availableWidth
                height: Math.max(scroll.availableHeight, loadedItem ? loadedItem.implicitHeight : 0)
                sourceComponent: root.selectedTab === "tasks" ? tasks
                    : root.selectedTab === "monitoring" ? monitoring
                    : root.selectedTab === "wallpapers" ? wallpapers : dashboard
            }
        }
    }
    Component {
        id: dashboard
        DashboardContent {
            snapshot: root.snapshot
            viewState: root.viewState
            onIntentRequested: intent => root.intentRequested(intent)
        }
    }
    Component {
        id: tasks
        TasksContent {
            snapshot: root.snapshot
            viewState: root.viewState
            onIntentRequested: intent => root.intentRequested(intent)
        }
    }
    Component { id: monitoring; MonitoringContent {} }
    Component {
        id: wallpapers
        WallpapersContent { screenName: root.viewState.ownerScreenName || "" }
    }
}
