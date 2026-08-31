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
                spacing: Metrics.spacingMedium

                GridLayout {
                    id: dashboardGrid
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Metrics.spacingMedium
                    rowSpacing: Metrics.spacingMedium

                    Shared.Surface {
                        id: hardwarePanel
                        Layout.row: 0
                        Layout.column: 0
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredHeight: 356
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

                            SystemMetricBlock { metricId: "cpu"
                                label: I18n.tr("center_notch.monitoring.cpu")
                                iconName: "memory"
                                accessibleName: I18n.tr("center_notch.monitoring.cpu")
                                percent: SystemMonitorService.snapshot.cpu?.percent ?? null
                                secondaryText: root.telemetryText(SystemMonitorService.snapshot.cpu)
                                severity: SystemMonitorService.snapshot.cpu?.severity || "neutral"
                                compact: true
                            }
                            SystemMetricBlock { metricId: "ram"
                                label: I18n.tr("center_notch.monitoring.ram")
                                iconName: "memory_alt"
                                accessibleName: I18n.tr("center_notch.monitoring.ram")
                                percent: SystemMonitorService.snapshot.ram?.percent ?? null
                                secondaryText: root.capacityText(SystemMonitorService.snapshot.ram)
                                compact: true
                            }
                            SystemMetricBlock { metricId: "gpu"
                                label: I18n.tr("center_notch.monitoring.gpu")
                                iconName: "developer_board"
                                accessibleName: I18n.tr("center_notch.monitoring.gpu")
                                percent: SystemMonitorService.snapshot.gpu?.percent ?? null
                                secondaryText: root.telemetryText(SystemMonitorService.snapshot.gpu)
                                severity: SystemMonitorService.snapshot.gpu?.severity || "neutral"
                                compact: true
                            }
                            SystemMetricBlock { metricId: "vram"
                                label: I18n.tr("center_notch.monitoring.vram")
                                iconName: "video_settings"
                                accessibleName: I18n.tr("center_notch.monitoring.vram")
                                percent: SystemMonitorService.snapshot.vram?.percent ?? null
                                secondaryText: root.capacityText(SystemMonitorService.snapshot.vram)
                                compact: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Metrics.spacingSmall

                                SystemMetricBlock { metricId: "disk"
                                    Layout.fillWidth: true
                                    label: I18n.tr("center_notch.monitoring.disk")
                                    iconName: "hard_drive"
                                    accessibleName: I18n.tr("center_notch.monitoring.disk")
                                    percent: SystemMonitorService.snapshot.disk?.percent ?? null
                                    secondaryText: root.capacityText(SystemMonitorService.snapshot.disk)
                                    compact: true
                                }
                                SystemMetricBlock { metricId: "network"
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
                        }
                    }

                    Shared.Surface {
                        id: processesPanel
                        Layout.row: 0
                        Layout.column: 1
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredHeight: 356
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
                                    text: "Process"
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

                Shared.Surface {
                    Layout.fillWidth: true
                    tone: "elevated"
                    radius: Metrics.radiusMedium
                    padding: Metrics.spacingMedium
                    Layout.minimumHeight: 82
                    Layout.preferredHeight: 82

                    ColumnLayout {
                        id: activeColumn
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
