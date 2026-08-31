pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import qs.Titonium.Services.SystemMonitor
import qs.Titonium.Shared as Shared
import qs.Titonium.Theme

FocusScope {
    id: root

    property string pageId: "monitoring"
    signal feedbackRequested(string key)

    function formatBytes(value: var, rate: bool): string {
        const number = Number(value);
        if (!isFinite(number) || number < 0)
            return "—";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let scaled = number;
        let unit = 0;
        while (scaled >= 1024 && unit < units.length - 1) {
            scaled /= 1024;
            unit++;
        }
        const digits = scaled < 10 && unit > 0 ? 1 : 0;
        return scaled.toFixed(digits) + " " + units[unit] + (rate ? "/s" : "");
    }

    function percentText(value: var): string {
        const number = Number(value);
        return isFinite(number) && number >= 0 ? Math.round(number) + "%" : "—";
    }

    function capacityText(value: var): string {
        if (!value)
            return "—";
        return root.formatBytes(value.usedBytes, false) + " / "
            + root.formatBytes(value.totalBytes, false);
    }

    function temperatureText(value: var): string {
        return typeof value?.temperatureC === "number"
            ? Math.round(value.temperatureC) + "°C" : "—";
    }

    function wattsText(value: var): string {
        return typeof value?.watts === "number"
            ? value.watts.toFixed(1) + " W" : "—";
    }

    component MetricBar: Item {
        id: metricRoot
        required property string label
        required property var value
        required property string detail
        property color fillColor: Theme.accent

        Layout.fillWidth: true
        Layout.preferredHeight: 34

        RowLayout {
            anchors.fill: parent
            spacing: Metrics.spacingSmall

            Shared.TextLabel {
                Layout.preferredWidth: 40
                text: metricRoot.label
                variant: "caption"
                strong: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 17
                radius: height / 2
                color: Theme.surfaceInteractive

                Rectangle {
                    width: {
                        const number = Number(metricRoot.value);
                        return isFinite(number) && number > 0
                            ? parent.width * Math.min(100, number) / 100 : 0;
                    }
                    height: parent.height
                    radius: parent.radius
                    color: metricRoot.fillColor
                }

                Shared.TextLabel {
                    anchors.centerIn: parent
                    text: root.percentText(metricRoot.value)
                    variant: "caption"
                    strong: true
                }
            }

            Shared.TextLabel {
                Layout.preferredWidth: 86
                text: metricRoot.detail
                variant: "caption"
                tone: "secondary"
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Metrics.spacingMedium

        RowLayout {
            Layout.fillWidth: true

            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("center_notch.monitoring.title")
                variant: "title"
                strong: true
            }
            Shared.TextLabel {
                text: SystemMonitorService.live
                    ? I18n.tr("center_notch.monitoring.live") + " · 2s"
                    : I18n.tr("center_notch.monitoring.paused")
                variant: "caption"
                tone: SystemMonitorService.live ? "success" : "secondary"
            }
        }

        QtControls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: Metrics.spacingMedium

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Metrics.spacingMedium
                    rowSpacing: Metrics.spacingMedium

                    ColumnLayout {
                        id: hardwarePanel
                        Layout.row: 0
                        Layout.column: 0
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Metrics.spacingSmall

                        RowLayout {
                            Layout.fillWidth: true

                            Shared.Icon {
                                name: "memory"
                                size: 20
                                tone: "accent"
                                accessibleName: I18n.tr("center_notch.monitoring.title")
                            }
                            Shared.TextLabel {
                                Layout.fillWidth: true
                                text: I18n.tr("center_notch.monitoring.title").toUpperCase()
                                variant: "label"
                                strong: true
                            }
                        }

                        Shared.Surface {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 132
                            tone: "elevated"
                            radius: Metrics.radiusMedium
                            padding: Metrics.spacingMedium

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Metrics.spacingSmall

                                RowLayout {
                                    Layout.fillWidth: true
                                    Shared.Icon {
                                        name: "memory"
                                        size: 16
                                        tone: "accent"
                                        accessibleName: I18n.tr("center_notch.monitoring.cpu")
                                    }
                                    Shared.TextLabel {
                                        Layout.fillWidth: true
                                        text: I18n.tr("center_notch.monitoring.cpu").toUpperCase()
                                        variant: "label"
                                        strong: true
                                    }
                                    Shared.TextLabel {
                                        text: root.percentText(SystemMonitorService.snapshot.cpu?.percent)
                                        variant: "label"
                                        tone: "accent"
                                        strong: true
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Metrics.spacingMedium

                                    Item {
                                        Layout.preferredWidth: 72
                                        Layout.preferredHeight: 72

                                        Shape {
                                            anchors.fill: parent
                                            antialiasing: true

                                            ShapePath {
                                                strokeColor: Theme.surfaceInteractive
                                                strokeWidth: 7
                                                fillColor: "transparent"
                                                capStyle: ShapePath.RoundCap
                                                PathAngleArc {
                                                    centerX: 36; centerY: 36
                                                    radiusX: 30; radiusY: 30
                                                    startAngle: 140; sweepAngle: 260
                                                }
                                            }
                                            ShapePath {
                                                strokeColor: Theme.accent
                                                strokeWidth: 7
                                                fillColor: "transparent"
                                                capStyle: ShapePath.RoundCap
                                                PathAngleArc {
                                                    centerX: 36; centerY: 36
                                                    radiusX: 30; radiusY: 30
                                                    startAngle: 140
                                                    sweepAngle: 260 * Math.max(0, Math.min(100,
                                                        Number(SystemMonitorService.snapshot.cpu?.percent) || 0)) / 100
                                                }
                                            }
                                        }
                                        Shared.TextLabel {
                                            anchors.centerIn: parent
                                            text: root.percentText(SystemMonitorService.snapshot.cpu?.percent)
                                            variant: "label"
                                            strong: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: Metrics.spacingXSmall

                                        Shared.TextLabel {
                                            text: "100%"
                                            variant: "caption"
                                            tone: "secondary"
                                        }
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Row {
                                                anchors.fill: parent
                                                spacing: 2
                                                Repeater {
                                                    model: SystemMonitorService.cpuHistory
                                                    Rectangle {
                                                        required property var modelData
                                                        width: Math.max(2, (parent.width - 46) / 24)
                                                        height: Math.max(3, parent.height
                                                            * Math.max(0.08, Math.min(1,
                                                                Number(modelData) / 100)))
                                                        anchors.bottom: parent.bottom
                                                        radius: 1
                                                        color: Theme.accent
                                                    }
                                                }
                                            }
                                        }
                                        Shared.TextLabel {
                                            text: "0%"
                                            variant: "caption"
                                            tone: "secondary"
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Shared.TextLabel {
                                        Layout.fillWidth: true
                                        text: "Temp: " + root.temperatureText(SystemMonitorService.snapshot.cpu)
                                        variant: "caption"
                                        tone: "secondary"
                                    }
                                    Shared.TextLabel {
                                        text: root.wattsText(SystemMonitorService.snapshot.cpu)
                                        variant: "caption"
                                        tone: "secondary"
                                    }
                                }
                            }
                        }

                        Shared.Surface {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 86
                            tone: "elevated"
                            radius: Metrics.radiusMedium
                            padding: Metrics.spacingMedium

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Metrics.spacingXSmall
                                RowLayout {
                                    Layout.fillWidth: true
                                    Shared.Icon {
                                        name: "memory_alt"
                                        size: 16
                                        tone: "success"
                                        accessibleName: I18n.tr("center_notch.monitoring.ram")
                                    }
                                    Shared.TextLabel {
                                        Layout.fillWidth: true
                                        text: I18n.tr("center_notch.monitoring.ram").toUpperCase()
                                        variant: "label"
                                        strong: true
                                    }
                                    Shared.TextLabel {
                                        text: root.capacityText(SystemMonitorService.snapshot.ram)
                                        variant: "caption"
                                        tone: "secondary"
                                    }
                                }
                                MetricBar {
                                    label: "RAM"
                                    value: SystemMonitorService.snapshot.ram?.percent
                                    detail: root.percentText(SystemMonitorService.snapshot.ram?.percent)
                                    fillColor: Theme.success
                                }
                            }
                        }

                        Shared.Surface {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 132
                            tone: "elevated"
                            radius: Metrics.radiusMedium
                            padding: Metrics.spacingMedium

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Metrics.spacingXSmall
                                RowLayout {
                                    Layout.fillWidth: true
                                    Shared.Icon {
                                        name: "developer_board"
                                        size: 16
                                        tone: "accent"
                                        accessibleName: I18n.tr("center_notch.monitoring.gpu")
                                    }
                                    Shared.TextLabel {
                                        Layout.fillWidth: true
                                        text: I18n.tr("center_notch.monitoring.gpu").toUpperCase()
                                        variant: "label"
                                        strong: true
                                    }
                                    Shared.TextLabel {
                                        text: root.temperatureText(SystemMonitorService.snapshot.gpu)
                                            + " · " + root.wattsText(SystemMonitorService.snapshot.gpu)
                                        variant: "caption"
                                        tone: "secondary"
                                    }
                                }
                                MetricBar {
                                    id: gpuBar
                                    label: "GPU"
                                    value: SystemMonitorService.snapshot.gpu?.percent
                                    detail: root.percentText(SystemMonitorService.snapshot.gpu?.percent)
                                    fillColor: Theme.accent
                                }
                                MetricBar {
                                    id: vramBar
                                    label: "VRAM"
                                    value: SystemMonitorService.snapshot.vram?.percent
                                    detail: root.capacityText(SystemMonitorService.snapshot.vram)
                                    fillColor: Theme.success
                                }
                            }
                        }
                    }

                    Shared.Surface {
                        id: processesPanel
                        Layout.row: 0
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredHeight: 382
                        tone: "elevated"
                        radius: Metrics.radiusMedium
                        padding: Metrics.spacingMedium

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Metrics.spacingSmall

                            RowLayout {
                                Layout.fillWidth: true
                                Shared.TextLabel {
                                    Layout.fillWidth: true
                                    text: I18n.tr("center_notch.monitoring.top_processes").toUpperCase()
                                    variant: "label"
                                    strong: true
                                }
                                Shared.TextLabel {
                                    visible: SystemMonitorService.processesStale
                                    text: I18n.tr("center_notch.monitoring.stale")
                                    variant: "caption"
                                    tone: "warning"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Metrics.spacingSmall
                                Shared.TextLabel {
                                    Layout.fillWidth: true
                                    text: "PROCESS"
                                    variant: "caption"
                                    tone: "secondary"
                                }
                                Shared.TextLabel {
                                    Layout.preferredWidth: 52
                                    text: I18n.tr("center_notch.monitoring.process_cpu")
                                    variant: "caption"
                                    tone: "secondary"
                                    horizontalAlignment: Text.AlignRight
                                }
                                Shared.TextLabel {
                                    Layout.preferredWidth: 72
                                    text: "MEM"
                                    variant: "caption"
                                    tone: "secondary"
                                    horizontalAlignment: Text.AlignRight
                                }
                                Shared.TextLabel {
                                    Layout.preferredWidth: 56
                                    text: "STATUS"
                                    variant: "caption"
                                    tone: "secondary"
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Repeater {
                                model: SystemMonitorService.processes
                                SystemProcessRow {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    process: modelData
                                    rank: index + 1
                                    memoryText: root.formatBytes(modelData.rssBytes, false)
                                }
                            }

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                visible: SystemMonitorService.processes.length === 0
                                text: I18n.tr("center_notch.monitoring.no_processes")
                                tone: "secondary"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Metrics.spacingMedium

                    SystemMetricBlock {
                        metricId: "disk"
                        Layout.fillWidth: true
                        label: I18n.tr("center_notch.monitoring.disk")
                        iconName: "hard_drive"
                        accessibleName: I18n.tr("center_notch.monitoring.disk")
                        percent: SystemMonitorService.snapshot.disk?.percent ?? null
                        secondaryText: root.capacityText(SystemMonitorService.snapshot.disk)
                        compact: true
                    }
                    SystemMetricBlock {
                        metricId: "network"
                        Layout.fillWidth: true
                        label: I18n.tr("center_notch.monitoring.network")
                        iconName: "swap_vert"
                        accessibleName: I18n.tr("center_notch.monitoring.network")
                        networkMode: true
                        downloadText: "↓ " + root.formatBytes(
                            SystemMonitorService.snapshot.network?.downBps, true)
                        uploadText: "↑ " + root.formatBytes(
                            SystemMonitorService.snapshot.network?.upBps, true)
                        compact: true
                    }
                }

                Shared.Surface {
                    Layout.fillWidth: true
                    Layout.minimumHeight: 82
                    Layout.preferredHeight: 82
                    tone: "elevated"
                    radius: Metrics.radiusMedium
                    padding: Metrics.spacingMedium

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Metrics.spacingSmall

                        Shared.TextLabel {
                            text: I18n.tr("center_notch.monitoring.active").toUpperCase()
                            variant: "caption"
                            strong: true
                        }

                        ListView {
                            id: activityList
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            visible: CenterActivityService.activities.length > 0
                            orientation: ListView.Horizontal
                            spacing: Metrics.spacingSmall
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: CenterActivityService.activities

                            delegate: CenterActivityCard {
                                required property var modelData
                                activity: modelData
                                now: SystemMonitorService.hotSampleAt
                                height: 48
                            }

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    if (Math.abs(event.angleDelta.x) <= Math.abs(event.angleDelta.y)) {
                                        event.accepted = false;
                                        return;
                                    }
                                    activityList.contentX = Math.max(0, Math.min(
                                        activityList.contentWidth - activityList.width,
                                        activityList.contentX - event.angleDelta.x));
                                    event.accepted = true;
                                }
                            }
                        }

                        Shared.TextLabel {
                            Layout.fillWidth: true
                            visible: CenterActivityService.activities.length === 0
                            text: I18n.tr("center_notch.monitoring.no_activities")
                            tone: "secondary"
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: SystemMonitorService.start()
    Component.onDestruction: SystemMonitorService.stop()
}
