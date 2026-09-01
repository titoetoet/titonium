pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Titonium.Core.Runtime
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

    function frequencyText(value: var): string {
        return typeof value?.frequencyGhz === "number"
            ? value.frequencyGhz.toFixed(2) + " GHz" : "—";
    }

    function gpuClockText(value: var): string {
        const number = Number(value);
        if (!isFinite(number) || number < 0)
            return "—";
        return number >= 1000
            ? (number / 1000).toFixed(2) + " GHz"
            : Math.round(number) + " MHz";
    }

    function usageColor(value: var): color {
        const number = Number(value);
        if (isFinite(number) && number >= 90)
            return Theme.danger;
        if (isFinite(number) && number >= 70)
            return Theme.warning;
        return Theme.accent;
    }

    readonly property real cpuVal: Math.max(0, Math.min(100, Number(SystemMonitorService.snapshot.cpu?.percent) || 0))
    readonly property real ramVal: Math.max(0, Math.min(100, Number(SystemMonitorService.snapshot.ram?.percent) || 0))
    readonly property real gpuVal: Math.max(0, Math.min(100, Number(SystemMonitorService.snapshot.gpu?.percent) || 0))
    readonly property real storageVal: Math.max(0, Math.min(100, Number(SystemMonitorService.snapshot.storage?.percent) || 0))

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ================= HEADER =================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 6

            Shared.Icon {
                name: "speed"
                size: 18
                tone: "accent"
                color: Theme.accent
                accessibleName: I18n.tr("center_notch.monitoring.title")
            }

            Shared.TextLabel {
                Layout.fillWidth: true
                text: I18n.tr("center_notch.monitoring.title").toUpperCase()
                variant: "title"
                strong: true
                color: Theme.textPrimary
                font.pixelSize: 14
                font.letterSpacing: 0.5
            }

            RowLayout {
                spacing: 4

                Rectangle {
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: SystemMonitorService.live ? Theme.success : Theme.textSecondary
                }

                Shared.TextLabel {
                    text: SystemMonitorService.live
                        ? I18n.tr("center_notch.monitoring.live")
                        : I18n.tr("center_notch.monitoring.paused")
                    variant: "caption"
                    tone: SystemMonitorService.live ? "success" : "secondary"
                    font.pixelSize: 11
                }
            }

            Shared.Button {
                variant: "quiet"
                iconName: "close"
                size: "small"
                iconColor: Theme.textSecondary
                accessibleName: I18n.tr("center_notch.monitoring.close")
                onTriggered: CenterNotchCoordinator.close()
            }
        }

        // ================= 2-COLUMN HARDWARE & PROCESSES GRID =================
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 10
            rowSpacing: 6

            // ================= LEFT: HARDWARE MONITORING =================
            ColumnLayout {
                id: hardwarePanel
                Layout.row: 0
                Layout.column: 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                Shared.TextLabel {
                    text: I18n.tr("center_notch.monitoring.hardware").toUpperCase()
                    variant: "label"
                    strong: true
                    color: Theme.textPrimary
                    font.pixelSize: 12
                    font.letterSpacing: 0.5
                }

                // 1. CPU USAGE CARD
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 110
                    radius: Metrics.radiusSmall
                    color: Theme.surfaceElevated
                    border.width: 1
                    border.color: Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Title Row
                        RowLayout {
                            Layout.fillWidth: true

                            RowLayout {
                                spacing: 5
                                Shared.Icon {
                                    name: "developer_board"
                                    size: 15
                                    color: Theme.textSecondary
                                    accessibleName: I18n.tr("center_notch.monitoring.cpu")
                                }
                                Shared.TextLabel {
                                    text: I18n.tr("center_notch.monitoring.cpu_usage").toUpperCase()
                                    variant: "body"
                                    strong: true
                                    color: Theme.textPrimary
                                    font.pixelSize: 11
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Top Right Mini Indicator
                            Rectangle {
                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 5
                                radius: 2.5
                                color: Theme.surfaceInteractive

                                Rectangle {
                                    width: parent.width * root.cpuVal / 100
                                    height: parent.height
                                    radius: 2.5
                                    color: root.usageColor(root.cpuVal)
                                }
                            }
                        }

                        // Middle Section: Circular Gauge + Live Frequency Waveform
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 8

                            // Left: Radial Arc Gauge
                            Item {
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                Layout.alignment: Qt.AlignVCenter

                                Shape {
                                    anchors.fill: parent
                                    antialiasing: true

                                    ShapePath {
                                        strokeColor: Theme.surfaceInteractive
                                        strokeWidth: 5.5
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        PathAngleArc {
                                            centerX: 32; centerY: 32
                                            radiusX: 26; radiusY: 26
                                            startAngle: 140; sweepAngle: 260
                                        }
                                    }

                                    ShapePath {
                                        strokeColor: root.usageColor(root.cpuVal)
                                        strokeWidth: 5.5
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        PathAngleArc {
                                            centerX: 32; centerY: 32
                                            radiusX: 26; radiusY: 26
                                            startAngle: 140
                                            sweepAngle: 260 * root.cpuVal / 100
                                        }
                                    }
                                }

                                Shared.TextLabel {
                                    anchors.centerIn: parent
                                    text: root.percentText(SystemMonitorService.snapshot.cpu?.percent)
                                    variant: "title"
                                    strong: true
                                    color: Theme.textPrimary
                                    font.pixelSize: 14
                                }
                            }

                            // Right: Live Frequency Waveform / Line Chart
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 3

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumWidth: 70
                                    Layout.minimumHeight: 44

                                    Row {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        z: 1
                                        spacing: 6

                                        Row {
                                            spacing: 2
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 8; height: 2; radius: 1
                                                color: Theme.accent
                                            }
                                            Shared.TextLabel {
                                                text: I18n.tr("center_notch.monitoring.utilization")
                                                color: Theme.textSecondary
                                                font.pixelSize: 8
                                            }
                                        }
                                        Row {
                                            spacing: 2
                                            Rectangle {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 8; height: 2; radius: 1
                                                color: Theme.danger
                                            }
                                            Shared.TextLabel {
                                                text: I18n.tr("center_notch.monitoring.temperature_short")
                                                color: Theme.textSecondary
                                                font.pixelSize: 8
                                            }
                                        }
                                    }

                                    // Horizontal Grid Lines
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        y: 2
                                        height: 1
                                        color: Theme.surfaceInteractive
                                    }
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 1
                                        color: Theme.surfaceInteractive
                                    }
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        y: parent.height - 2
                                        height: 1
                                        color: Theme.surfaceInteractive
                                    }

                                    Item {
                                        id: cpuHistoryChart
                                        anchors.fill: parent
                                        property var curvePoints: []
                                        property var temperatureCurvePoints: []
                                        property var usageAreaPoints: []
                                        property var temperatureAreaPoints: []

                                        function curveFor(source: var, smoothing: real): var {
                                            const history = (source || [])
                                                .slice(-60).filter(value =>
                                                    typeof value === "number" && isFinite(value));
                                            if (width <= 0 || height <= 0 || history.length < 2)
                                                return [];

                                            const smoothed = [];
                                            for (let i = 0; i < history.length; i++) {
                                                smoothed.push(i === 0 ? history[i]
                                                    : smoothed[i - 1] * (1 - smoothing)
                                                        + history[i] * smoothing);
                                            }

                                            const verticalMax = 100;
                                            const step = width / 59;
                                            const startX = width - (smoothed.length - 1) * step;
                                            const curve = [];
                                            const subdivisions = 3;

                                            for (let i = 0; i < smoothed.length - 1; i++) {
                                                const p0 = smoothed[Math.max(0, i - 1)];
                                                const p1 = smoothed[i];
                                                const p2 = smoothed[i + 1];
                                                const p3 = smoothed[Math.min(
                                                    smoothed.length - 1, i + 2)];
                                                for (let part = 0; part < subdivisions; part++) {
                                                    const t = part / subdivisions;
                                                    const t2 = t * t;
                                                    const t3 = t2 * t;
                                                    const value = 0.5 * ((2 * p1)
                                                        + (-p0 + p2) * t
                                                        + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                                                        + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
                                                    const boundedValue = Math.max(
                                                        Math.min(p1, p2), Math.min(
                                                            Math.max(p1, p2), value));
                                                    curve.push(Qt.point(
                                                        startX + (i + t) * step,
                                                        height - 4 - Math.max(0, Math.min(1,
                                                            boundedValue / verticalMax)) * (height - 8)));
                                                }
                                            }
                                            const lastIndex = smoothed.length - 1;
                                            curve.push(Qt.point(width,
                                                height - 4 - Math.max(0, Math.min(1,
                                                    smoothed[lastIndex] / verticalMax))
                                                    * (height - 8)));
                                            return curve;
                                        }

                                        function areaFor(curve: var): var {
                                            if (!curve || curve.length < 2)
                                                return [];
                                            return [Qt.point(curve[0].x, height - 3)]
                                                .concat(curve)
                                                .concat([Qt.point(curve[curve.length - 1].x,
                                                    height - 3)]);
                                        }

                                        function rebuild(): void {
                                            curvePoints = curveFor(
                                                SystemMonitorService.cpuHistory, 0.32);
                                            temperatureCurvePoints = curveFor(
                                                SystemMonitorService.cpuTemperatureHistory, 0.20);
                                            usageAreaPoints = areaFor(curvePoints);
                                            temperatureAreaPoints = areaFor(
                                                temperatureCurvePoints);
                                        }

                                        onWidthChanged: rebuild()
                                        onHeightChanged: rebuild()
                                        Component.onCompleted: rebuild()

                                        Connections {
                                            target: SystemMonitorService
                                            function onHotSampleAtChanged(): void {
                                                cpuHistoryChart.rebuild();
                                            }
                                        }

                                        Shape {
                                            anchors.fill: parent
                                            asynchronous: true
                                            preferredRendererType: Shape.SoftwareRenderer

                                            ShapePath {
                                                strokeColor: "transparent"
                                                fillColor: Qt.rgba(Theme.danger.r,
                                                    Theme.danger.g, Theme.danger.b, 0.10)

                                                PathPolyline {
                                                    path: cpuHistoryChart.temperatureAreaPoints
                                                }
                                            }

                                            ShapePath {
                                                strokeColor: "transparent"
                                                fillColor: Qt.rgba(Theme.accent.r,
                                                    Theme.accent.g, Theme.accent.b, 0.16)

                                                PathPolyline {
                                                    path: cpuHistoryChart.usageAreaPoints
                                                }
                                            }

                                            ShapePath {
                                                strokeColor: Theme.accent
                                                strokeWidth: 1.4
                                                fillColor: "transparent"
                                                capStyle: ShapePath.RoundCap
                                                joinStyle: ShapePath.RoundJoin

                                                PathPolyline {
                                                    path: cpuHistoryChart.curvePoints
                                                }
                                            }

                                            ShapePath {
                                                strokeColor: Theme.danger
                                                strokeWidth: 1.2
                                                fillColor: "transparent"
                                                capStyle: ShapePath.RoundCap
                                                joinStyle: ShapePath.RoundJoin

                                                PathPolyline {
                                                    path: cpuHistoryChart.temperatureCurvePoints
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Bottom Telemetry Row
                        RowLayout {
                            Layout.fillWidth: true

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                text: SystemMonitorService.snapshot.cpu?.name || I18n.tr("center_notch.monitoring.cpu")
                                color: Theme.textPrimary
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Shared.TextLabel {
                                text: I18n.tr("center_notch.monitoring.temperature", { value: root.temperatureText(SystemMonitorService.snapshot.cpu) })
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }

                            Shared.TextLabel {
                                text: I18n.tr("center_notch.monitoring.frequency_value", { value: root.frequencyText(SystemMonitorService.snapshot.cpu) })
                                color: Theme.accent
                                font.pixelSize: 11
                                strong: true
                            }
                        }
                    }
                }

                // 2. RAM USAGE CARD
                Item {
                    id: memoryStorageRow
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 84
                    readonly property real gap: 6

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0,
                            (memoryStorageRow.width - memoryStorageRow.gap) * 2 / 3)
                        radius: Metrics.radiusSmall
                        color: Theme.surfaceElevated
                        border.width: 1
                        border.color: Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Title Row
                        RowLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                spacing: 5
                                Shared.Icon {
                                    name: "memory"
                                    size: 15
                                    color: Theme.textSecondary
                                    accessibleName: I18n.tr("center_notch.monitoring.ram")
                                }
                                Shared.TextLabel {
                                    text: I18n.tr("center_notch.monitoring.ram_usage").toUpperCase()
                                    variant: "body"
                                    strong: true
                                    color: Theme.textPrimary
                                    font.pixelSize: 11
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Shared.TextLabel {
                                Layout.minimumWidth: 0
                                text: SystemMonitorService.snapshot.ram
                                    ? root.formatBytes(SystemMonitorService.snapshot.ram.totalBytes, false) : "—"
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                elide: Text.ElideLeft
                            }
                        }

                        // Value: 65% (10.4GB / 16.0GB)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Shared.TextLabel {
                                text: root.percentText(SystemMonitorService.snapshot.ram?.percent)
                                strong: true
                                color: root.usageColor(root.ramVal)
                                font.pixelSize: 13
                            }

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: "(" + (SystemMonitorService.snapshot.ram
                                    ? root.formatBytes(SystemMonitorService.snapshot.ram.usedBytes, false)
                                        + " / " + root.formatBytes(SystemMonitorService.snapshot.ram.totalBytes, false)
                                    : "—") + ")"
                                color: Theme.textSecondary
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        // Progress Bar
                        Rectangle {
                            id: ramBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            radius: 4
                            color: Theme.surfaceInteractive

                            Rectangle {
                                width: parent.width * root.ramVal / 100
                                height: parent.height
                                radius: 4
                                color: root.usageColor(root.ramVal)
                            }
                        }

                        // Bottom Telemetry
                        RowLayout {
                            Layout.fillWidth: true
                            Shared.TextLabel {
                                Layout.fillWidth: true
                                text: I18n.tr("center_notch.monitoring.ram")
                                color: Theme.textSecondary
                                font.pixelSize: 10
                            }
                            Shared.TextLabel {
                                text: I18n.tr("center_notch.monitoring.total", { value: SystemMonitorService.snapshot.ram ? root.formatBytes(SystemMonitorService.snapshot.ram.totalBytes, false) : "—" })
                                color: Theme.textSecondary
                                font.pixelSize: 10
                            }
                        }
                    }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(0,
                            (memoryStorageRow.width - memoryStorageRow.gap) / 3)
                        radius: Metrics.radiusSmall
                        color: Theme.surfaceElevated
                        border.width: 1
                        border.color: Theme.border

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Shared.Icon {
                                    name: "storage"
                                    size: 14
                                    color: Theme.textSecondary
                                    accessibleName: I18n.tr("center_notch.monitoring.storage")
                                }
                                Shared.TextLabel {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: I18n.tr("center_notch.monitoring.storage").toUpperCase()
                                    strong: true
                                    color: Theme.textPrimary
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }

                            Item {
                                Layout.preferredWidth: 44
                                Layout.preferredHeight: 44
                                Layout.alignment: Qt.AlignHCenter

                                Shape {
                                    anchors.fill: parent
                                    antialiasing: true

                                    ShapePath {
                                        strokeColor: Theme.surfaceInteractive
                                        strokeWidth: 5
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        PathAngleArc {
                                            centerX: 22; centerY: 22
                                            radiusX: 17; radiusY: 17
                                            startAngle: 140; sweepAngle: 260
                                        }
                                    }

                                    ShapePath {
                                        strokeColor: root.usageColor(root.storageVal)
                                        strokeWidth: 5
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        PathAngleArc {
                                            centerX: 22; centerY: 22
                                            radiusX: 17; radiusY: 17
                                            startAngle: 140
                                            sweepAngle: 260 * root.storageVal / 100
                                        }
                                    }
                                }

                                Shared.TextLabel {
                                    anchors.centerIn: parent
                                    text: root.percentText(
                                        SystemMonitorService.snapshot.storage?.percent)
                                    strong: true
                                    color: Theme.textPrimary
                                    font.pixelSize: 12
                                }
                            }

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: root.capacityText(SystemMonitorService.snapshot.storage)
                                color: Theme.textSecondary
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // 3. GPU USAGE CARD
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 78
                    radius: Metrics.radiusSmall
                    color: Theme.surfaceElevated
                    border.width: 1
                    border.color: Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Title Row
                        RowLayout {
                            Layout.fillWidth: true
                            RowLayout {
                                spacing: 5
                                Shared.Icon {
                                    name: "videogame_asset"
                                    size: 15
                                    color: Theme.textSecondary
                                    accessibleName: I18n.tr("center_notch.monitoring.gpu")
                                }
                                Shared.TextLabel {
                                    text: I18n.tr("center_notch.monitoring.gpu_usage").toUpperCase()
                                    variant: "body"
                                    strong: true
                                    color: Theme.textPrimary
                                    font.pixelSize: 11
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Shared.TextLabel {
                                text: SystemMonitorService.snapshot.gpu?.name || I18n.tr("center_notch.monitoring.gpu")
                                Layout.maximumWidth: 160
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        // Value: 48%
                        Shared.TextLabel {
                            text: root.percentText(SystemMonitorService.snapshot.gpu?.percent)
                            strong: true
                            color: root.usageColor(root.gpuVal)
                            font.pixelSize: 13
                        }

                        // Progress Bar
                        Rectangle {
                            id: gpuBar
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            radius: 4
                            color: Theme.surfaceInteractive

                            Rectangle {
                                width: parent.width * root.gpuVal / 100
                                height: parent.height
                                radius: 4
                                color: root.usageColor(root.gpuVal)
                            }
                        }

                        // Bottom Telemetry
                        RowLayout {
                            Layout.fillWidth: true

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: I18n.tr("center_notch.monitoring.temperature", { value: root.temperatureText(SystemMonitorService.snapshot.gpu) })
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignLeft
                                elide: Text.ElideRight
                            }

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: I18n.tr("center_notch.monitoring.vram_value", { value: SystemMonitorService.snapshot.vram ? root.formatBytes(SystemMonitorService.snapshot.vram.usedBytes, false) + "/" + root.formatBytes(SystemMonitorService.snapshot.vram.totalBytes, false) : "—" })
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: I18n.tr("center_notch.monitoring.gpu_clock", { value: root.gpuClockText(SystemMonitorService.snapshot.gpu?.clockMhz) })
                                color: Theme.textSecondary
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideLeft
                            }
                        }
                    }
                }
            }

            // ================= RIGHT: TOP PROCESSES =================
            ColumnLayout {
                id: processesPanel
                Layout.row: 0
                Layout.column: 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                Shared.TextLabel {
                    text: I18n.tr("center_notch.monitoring.top_processes").toUpperCase()
                    variant: "label"
                    strong: true
                    color: Theme.textPrimary
                    font.pixelSize: 12
                    font.letterSpacing: 0.5
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Metrics.radiusSmall
                    color: Theme.surfaceElevated
                    border.width: 1
                    border.color: Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Table Column Headers
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 6
                            Layout.rightMargin: 6
                            spacing: 8

                            Item {
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 20

                                Shared.Icon {
                                    anchors.centerIn: parent
                                    name: "format_list_numbered"
                                    size: 14
                                    tone: "secondary"
                                    accessibleName: I18n.tr("center_notch.monitoring.process_rank")
                                }
                            }

                            Shared.TextLabel {
                                Layout.fillWidth: true
                                text: I18n.tr("center_notch.monitoring.process_name")
                                color: Theme.textSecondary
                                font.pixelSize: 11
                            }

                            Item {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 20

                                Shared.Icon {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "developer_board"
                                    size: 14
                                    color: Theme.accent
                                    accessibleName: I18n.tr("center_notch.monitoring.process_cpu")
                                }
                            }

                            Item {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 20

                                Shared.Icon {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "memory_alt"
                                    size: 14
                                    tone: "secondary"
                                    accessibleName: I18n.tr("center_notch.monitoring.process_memory")
                                }
                            }

                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Theme.border
                        }

                        // Process List Rows
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

                        Item { Layout.fillHeight: true }

                        Shared.TextLabel {
                            Layout.fillWidth: true
                            visible: SystemMonitorService.processes.length === 0
                            text: I18n.tr("center_notch.monitoring.no_processes")
                            color: Theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

    }

}
