pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Titonium.Core.Runtime
import "WeatherRules.js" as WeatherRules

QtObject {
    id: root

    property int consumerCount: 0
    property double lastUpdatedAt: 0
    property var currentSnapshot: WeatherRules.unavailable(new Date().getHours())
    property bool loading: false
    property bool failed: false

    readonly property var snapshot: root.currentSnapshot
    readonly property bool active: root.consumerCount > 0
    readonly property int refreshInterval: 30 * 60 * 1000

    function scheduleRefresh(): void {
        refreshTimer.stop();
        if (!root.active)
            return;
        refreshTimer.interval = root.refreshInterval;
        refreshTimer.start();
    }

    function refresh(): bool {
        if (weatherProcess.running)
            return false;
        root.loading = true;
        root.failed = false;
        weatherProcess.running = true;
        return true;
    }

    function acquire(): void {
        root.consumerCount += 1;
        if (root.lastUpdatedAt === 0
                || Date.now() - root.lastUpdatedAt >= root.refreshInterval)
            root.refresh();
        else
            root.scheduleRefresh();
    }

    function release(): void {
        root.consumerCount = Math.max(0, root.consumerCount - 1);
        if (!root.active)
            refreshTimer.stop();
    }

    function acceptResponse(raw: string): void {
        try {
            const parsed = JSON.parse(raw);
            const projected = WeatherRules.parse(parsed, new Date().getHours());
            if (!projected.available)
                throw new Error("missing current condition");
            root.currentSnapshot = projected;
            root.lastUpdatedAt = Date.now();
            root.failed = false;
        } catch (error) {
            Logger.warn("weather", "weather response was unavailable");
            root.failed = true;
        }
    }

    property Timer refreshTimer: Timer {
        repeat: false
        onTriggered: root.refresh()
    }

    property Process weatherProcess: Process {
        command: ["curl", "--fail", "--silent", "--show-error", "--max-time", "8",
            "--compressed", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            id: weatherOutput
            waitForEnd: true
        }
        stderr: StdioCollector { waitForEnd: true }
        onExited: exitCode => {
            root.loading = false;
            if (exitCode === 0)
                root.acceptResponse(weatherOutput.text);
            else {
                root.failed = true;
                Logger.warn("weather", "weather request failed with exit " + exitCode);
            }
            root.scheduleRefresh();
        }
    }
}
