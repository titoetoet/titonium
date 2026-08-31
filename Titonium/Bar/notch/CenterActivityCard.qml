pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Shared.Surface {
    id: root

    required property var activity
    required property double now
    readonly property string detail: {
        if (root.activity.source === "job")
            return Math.round(root.activity.progress) + "%";
        if (root.activity.source === "timer")
            return Math.max(0, Math.ceil((root.activity.deadline - root.now) / 60000)) + "m";
        return "";
    }

    width: 180
    height: 58
    tone: "elevated"
    radius: Metrics.radiusMedium
    padding: Metrics.spacingMedium
    Accessible.name: root.activity.label
    Accessible.description: root.detail

    RowLayout {
        anchors.fill: parent
        spacing: Metrics.spacingSmall

        Shared.Icon {
            name: root.activity.icon || "progress_activity"
            size: 22
            tone: "accent"
            accessibleName: root.activity.label
        }
        Shared.TextLabel {
            Layout.fillWidth: true
            text: root.activity.label
            variant: "caption"
            strong: true
            elide: Text.ElideRight
        }
        Shared.TextLabel {
            visible: root.detail.length > 0
            text: root.detail
            variant: "caption"
            tone: "secondary"
        }
    }
}
