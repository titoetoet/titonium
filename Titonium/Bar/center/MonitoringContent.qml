pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.SystemMonitor
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root
    property var snapshot: SystemMonitorService.snapshot
    property var processes: SystemMonitorService.processes
    implicitHeight: content.implicitHeight + Metrics.spacingLarge * 2
    function percent(value: var): string {
        return typeof value === "number" && Number.isFinite(value)
            ? Math.round(value) + "%" : I18n.tr("center.expanded.unavailable");
    }
    function capacity(value: var): string {
        return value && typeof value.usedBytes === "number" && typeof value.totalBytes === "number"
            ? (value.usedBytes / 1073741824).toFixed(1) + " / " + (value.totalBytes / 1073741824).toFixed(1) + " GiB" : "";
    }
    ColumnLayout {
        id: content
        x: Metrics.spacingLarge; y: Metrics.spacingLarge
        width: Math.max(0, root.width - Metrics.spacingLarge * 2)
        spacing: Metrics.spacingMedium
        Shared.TextLabel { text: I18n.tr("center.expanded.tab.monitoring"); variant: "titleSmall" }
        GridLayout {
            Layout.fillWidth: true
            columns: root.width < 520 ? 1 : 2
            columnSpacing: Metrics.spacingMedium; rowSpacing: Metrics.spacingMedium
            Repeater {
                model: ["cpu", "ram", "gpu", "vram", "storage"]
                Rectangle {
                    id: metric
                    required property string modelData
                    readonly property var value: root.snapshot?.[modelData] || null
                    Layout.fillWidth: true
                    implicitHeight: metricContent.implicitHeight + Metrics.spacingMedium * 2
                    radius: Metrics.radiusMedium; color: Theme.surfaceElevated
                    ColumnLayout {
                        id: metricContent
                        x: Metrics.spacingMedium; y: Metrics.spacingMedium
                        width: parent.width - Metrics.spacingMedium * 2
                        Shared.TextLabel { text: I18n.tr("center.expanded.metric." + metric.modelData); strong: true }
                        Shared.TextLabel { text: root.percent(metric.value?.percent); variant: "title" }
                        Shared.TextLabel {
                            Layout.fillWidth: true
                            text: metric.value?.name || root.capacity(metric.value)
                            visible: text.length > 0; tone: "secondary"; wrapMode: Text.Wrap
                        }
                        Shared.TextLabel {
                            visible: typeof metric.value?.temperatureC === "number"
                            text: visible ? Math.round(metric.value.temperatureC) + " °C" : ""
                            tone: "secondary"
                        }
                    }
                }
            }
        }
        Shared.TextLabel { text: I18n.tr("center.expanded.processes"); variant: "titleSmall" }
        Shared.TextLabel {
            visible: root.processes.length === 0
            text: I18n.tr("center.expanded.unavailable"); tone: "secondary"
        }
        Repeater {
            model: root.processes.slice(0, 10)
            RowLayout {
                required property var modelData
                id: processRow
                Layout.fillWidth: true
                Shared.TextLabel { Layout.fillWidth: true; text: processRow.modelData.name || ""; elide: Text.ElideRight }
                Shared.TextLabel { text: root.percent(processRow.modelData.cpuPercent); tone: "secondary" }
            }
        }
    }
}
