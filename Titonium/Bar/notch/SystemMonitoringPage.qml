pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QtControls
import QtQuick.Layouts
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

    function capacityText(value: var): string {
        if (!value)
            return "";
        return root.formatBytes(value.usedBytes, false) + " / "
            + root.formatBytes(value.totalBytes, false);
    }

    function telemetryText(value: var): string {
        if (!value)
            return "";
        const result = [];
        if (typeof value.temperatureC === "number")
            result.push(Math.round(value.temperatureC) + "°C");
        if (typeof value.watts === "number")
            result.push(value.watts.toFixed(1) + "W");
        return result.join(" · ");
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
                    ? I18n.tr("center_notch.monitoring.live")
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
                spacing: Metrics.spacingLarge

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Metrics.spacingMedium
                    rowSpacing: Metrics.spacingMedium

                    SystemMetricBlock { metricId: "cpu"
                        Layout.row: 0; Layout.column: 0
                        iconName: "memory"
                        accessibleName: I18n.tr("center_notch.monitoring.cpu")
                        percent: SystemMonitorService.snapshot.cpu?.percent ?? null
                        secondaryText: root.telemetryText(SystemMonitorService.snapshot.cpu)
                        severity: SystemMonitorService.snapshot.cpu?.severity || "neutral"
                    }
                    SystemMetricBlock { metricId: "gpu"
                        Layout.row: 0; Layout.column: 1
                        iconName: "developer_board"
                        accessibleName: I18n.tr("center_notch.monitoring.gpu")
                        percent: SystemMonitorService.snapshot.gpu?.percent ?? null
                        secondaryText: root.telemetryText(SystemMonitorService.snapshot.gpu)
                        severity: SystemMonitorService.snapshot.gpu?.severity || "neutral"
                    }
                    SystemMetricBlock { metricId: "ram"
                        Layout.row: 1; Layout.column: 0
                        iconName: "memory_alt"
                        accessibleName: I18n.tr("center_notch.monitoring.ram")
                        percent: SystemMonitorService.snapshot.ram?.percent ?? null
                        secondaryText: root.capacityText(SystemMonitorService.snapshot.ram)
                    }
                    SystemMetricBlock { metricId: "vram"
                        Layout.row: 1; Layout.column: 1
                        iconName: "video_settings"
                        accessibleName: I18n.tr("center_notch.monitoring.vram")
                        percent: SystemMonitorService.snapshot.vram?.percent ?? null
                        secondaryText: root.capacityText(SystemMonitorService.snapshot.vram)
                    }
                    SystemMetricBlock { metricId: "disk"
                        Layout.row: 2; Layout.column: 0
                        iconName: "hard_drive"
                        accessibleName: I18n.tr("center_notch.monitoring.disk")
                        percent: SystemMonitorService.snapshot.disk?.percent ?? null
                        secondaryText: root.capacityText(SystemMonitorService.snapshot.disk)
                    }
                    SystemMetricBlock { metricId: "network"
                        Layout.row: 2; Layout.column: 1
                        iconName: "swap_vert"
                        accessibleName: I18n.tr("center_notch.monitoring.network")
                        networkMode: true
                        downloadText: "↓ " + root.formatBytes(
                            SystemMonitorService.snapshot.network?.downBps, true)
                        uploadText: "↑ " + root.formatBytes(
                            SystemMonitorService.snapshot.network?.upBps, true)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Shared.TextLabel {
                        Layout.fillWidth: true
                        text: I18n.tr("center_notch.monitoring.top_processes")
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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Metrics.spacingXSmall

                    Repeater {
                        model: SystemMonitorService.processes
                        SystemProcessRow {
                            required property var modelData
                            Layout.fillWidth: true
                            process: modelData
                            memoryText: root.formatBytes(modelData.rssBytes, false)
                        }
                    }
                    Shared.TextLabel {
                        Layout.fillWidth: true
                        visible: SystemMonitorService.processes.length === 0
                        text: I18n.tr("center_notch.monitoring.no_processes")
                        tone: "secondary"
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Shared.TextLabel {
                    text: I18n.tr("center_notch.monitoring.active")
                    variant: "label"
                    strong: true
                }

                ListView {
                    id: activityList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    orientation: ListView.Horizontal
                    spacing: Metrics.spacingSmall
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: CenterActivityService.activities

                    delegate: CenterActivityCard {
                        required property var modelData
                        activity: modelData
                        now: SystemMonitorService.hotSampleAt
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
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Component.onCompleted: SystemMonitorService.start()
    Component.onDestruction: SystemMonitorService.stop()
}
