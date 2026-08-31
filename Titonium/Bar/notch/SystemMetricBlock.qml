pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

Shared.Surface {
    id: root

    required property string metricId
    required property string iconName
    required property string accessibleName
    property string label: ""
    property var percent: null
    property string primarySuffix: ""
    property string secondaryText: ""
    property string severity: "neutral"
    property bool networkMode: false
    property string downloadText: ""
    property string uploadText: ""
    property bool compact: false

    readonly property bool hasPercent: typeof root.percent === "number"
        && isFinite(root.percent) && root.percent >= 0
    readonly property string severityText: root.severity === "critical"
        ? I18n.tr("center_notch.monitoring.critical")
        : (root.severity === "warning"
            ? I18n.tr("center_notch.monitoring.warning") : "")
    readonly property string detailText: [
        root.label, root.hasPercent ? Math.round(root.percent) + "%" : "—",
        root.primarySuffix, root.secondaryText, root.severityText
    ].filter(value => value.length > 0).join(" · ")

    Layout.fillWidth: true
    Layout.minimumHeight: root.compact ? 58 : 84
    Layout.preferredHeight: root.compact ? 58 : 84
    tone: "interactive"
    radius: Metrics.radiusMedium
    padding: root.compact ? Metrics.spacingSmall : Metrics.spacingMedium
    borderColor: root.severity === "critical" ? Theme.danger
        : (root.severity === "warning" ? Theme.warning : Theme.border)
    Accessible.name: root.accessibleName
    Accessible.description: root.detailText

    ColumnLayout {
        anchors.fill: parent
        spacing: root.compact ? 3 : Metrics.spacingXSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Metrics.spacingSmall

            Item {
                Layout.preferredWidth: root.compact ? 20 : 28
                Layout.preferredHeight: root.compact ? 20 : 28

                Shared.Icon {
                    anchors.centerIn: parent
                    name: root.iconName
                    size: root.compact ? 18 : 24
                    tone: root.severity === "critical" ? "danger"
                        : (root.severity === "warning" ? "warning" : "accent")
                    accessibleName: root.accessibleName
                }

                HoverHandler { id: metricHover }
                QtControls.ToolTip.visible: metricHover.hovered
                QtControls.ToolTip.text: root.accessibleName
                QtControls.ToolTip.delay: 450
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                visible: root.label.length > 0
                text: root.label
                variant: root.compact ? "caption" : "label"
                strong: true
                elide: Text.ElideRight
            }

            Shared.TextLabel {
                visible: !root.networkMode && root.secondaryText.length > 0
                text: root.secondaryText
                variant: "caption"
                tone: "secondary"
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.compact ? 16 : 20

            Rectangle {
                visible: !root.networkMode
                anchors.fill: parent
                radius: height / 2
                color: Theme.surfaceElevated

                Rectangle {
                    width: root.hasPercent
                        ? parent.width * Math.max(0, Math.min(100, root.percent)) / 100 : 0
                    height: parent.height
                    radius: parent.radius
                    color: root.severity === "critical" ? Theme.danger
                        : (root.severity === "warning" ? Theme.warning : Theme.accent)
                }

                Shared.TextLabel {
                    anchors.centerIn: parent
                    text: root.hasPercent ? Math.round(root.percent) + "%" : "—"
                    variant: "caption"
                    strong: true
                }
            }

            RowLayout {
                visible: root.networkMode
                anchors.fill: parent
                spacing: Metrics.spacingSmall

                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.downloadText
                    variant: "caption"
                    strong: true
                }
                Shared.TextLabel {
                    Layout.fillWidth: true
                    text: root.uploadText
                    variant: "caption"
                    strong: true
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        Shared.TextLabel {
            Layout.fillWidth: true
            visible: !root.compact && root.primarySuffix.length > 0
            text: root.primarySuffix
            variant: "caption"
            tone: "secondary"
            elide: Text.ElideRight
        }
    }
}
