pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Shared.Surface {
    id: root
    required property var activity
    readonly property bool hasProgress: Number(root.activity.progress) >= 0
    readonly property string detail: {
        if (root.activity.source === "job" && root.hasProgress)
            return Math.round(root.activity.progress) + "%";
        if (root.activity.source === "timer" && Number(root.activity.deadline) > 0)
            return I18n.tr("center_notch.overview.activities.ends_at", {
                "value": Qt.formatTime(new Date(root.activity.deadline), "HH:mm")
            });
        return "";
    }
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    tone: "interactive"
    radius: Metrics.radiusMedium
    padding: Metrics.spacingSmall
    Accessible.name: root.activity.label
    Accessible.description: root.detail

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingXSmall
        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall
            Shared.Icon {
                name: root.activity.icon || "progress_activity"
                size: 20
                tone: root.activity.importance === "important" ? "warning" : "accent"
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
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            visible: root.hasProgress
            radius: 2
            color: Theme.border
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, Number(root.activity.progress) / 100))
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }
    }
}
