pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Column {
    id: root
    required property var group
    property bool expanded: false
    signal toggleRequested()
    spacing: Metrics.spacingSmall

    Shared.Button {
        width: parent.width
        visible: root.group.items.length > 1
        height: visible ? implicitHeight : 0
        label: I18n.tr("notification.group.label", {
            name: root.group.appName || I18n.tr("notification.toast.fallback_app"),
            count: root.group.items.length
        })
        iconName: root.expanded ? "expand_less" : "expand_more"
        variant: "quiet"
        contentAlignment: Qt.AlignLeft
        accessibleName: I18n.tr(root.expanded ? "notification.group.collapse" : "notification.group.expand", {
            name: root.group.appName || I18n.tr("notification.toast.fallback_app")
        })
        onTriggered: root.toggleRequested()
    }

    Repeater {
        model: root.expanded ? root.group.items : root.group.items.slice(0, 1)
        NotificationHistoryRow {
            required property var modelData
            width: root.width
            notification: modelData
            showSource: root.group.items.length === 1
            collapsedGroup: root.group.items.length > 1 && !root.expanded
            onExpandRequested: root.toggleRequested()
        }
    }
}
