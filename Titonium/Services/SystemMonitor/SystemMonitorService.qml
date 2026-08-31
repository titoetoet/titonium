pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Core.Runtime
import "SystemMonitorRules.js" as SystemMonitorRules

Singleton {
    id: root

    property bool activeState: false
    property bool liveState: false
    property double activationStartedAt: 0
    property double hotSampleAtState: 0
    property double processSampleAt: 0
    property double diskSampleAt: 0
    property double nextHotAt: 0
    property double nextProcessAt: 0
    property double nextDiskAt: 0
    property int generation: 0
    property int psGeneration: 0
    property int dfGeneration: 0
    property int discoveryGeneration: 0
    property var snapshotState: Object.freeze({
        cpu: null, gpu: null, ram: null, vram: null,
        disk: null, network: null
    })
    property var processesState: Object.freeze([])
    property bool processesStaleState: true
    property var previousCpu: null
    property var previousNetwork: null
    property double previousNetworkAt: 0
    property var sensorPaths: Object.freeze({})
    property var warningCounts: ({})

    readonly property bool active: root.activeState
    readonly property bool live: root.liveState
    readonly property double hotSampleAt: root.hotSampleAtState
    readonly property var snapshot: root.snapshotState
    readonly property var processes: root.processesState
    readonly property bool processesStale: root.processesStaleState

    function warn(category: string, message: string): void {
        const count = root.warningCounts[category] || 0;
        if (count >= 3)
            return;
        root.warningCounts[category] = count + 1;
        Logger.warn("system-monitor", message);
    }

    function readView(view: FileView): string {
        try {
            view.reload();
            return view.text();
        } catch (failure) {
            return "";
        }
    }

    function optionalScalar(view: FileView, divisor: double): var {
        if (!view.path)
            return null;
        return SystemMonitorRules.scalar(root.readView(view), divisor);
    }

    function sampleHot(now: double): void {
        const currentCpu = SystemMonitorRules.parseCpuStat(root.readView(cpuStatFile));
        const cpuPercent = SystemMonitorRules.cpuPercent(root.previousCpu, currentCpu);
        root.previousCpu = currentCpu;

        const memory = SystemMonitorRules.parseMeminfo(root.readView(meminfoFile));
        const currentNetwork = SystemMonitorRules.parseNetDev(root.readView(netDevFile));
        const network = SystemMonitorRules.networkRate(
            root.previousNetwork, currentNetwork, now - root.previousNetworkAt);
        root.previousNetwork = currentNetwork;
        root.previousNetworkAt = currentNetwork === null ? 0 : now;

        const gpuPercent = root.optionalScalar(gpuBusyFile, 1);
        const vramUsed = root.optionalScalar(vramUsedFile, 1);
        const vramTotal = root.optionalScalar(vramTotalFile, 1);
        const vram = SystemMonitorRules.capacity(vramUsed, vramTotal);
        const gpuTemperature = root.optionalScalar(gpuTemperatureFile, 1000);
        const gpuWatts = root.optionalScalar(gpuPowerFile, 1000000);
        const cpuTemperature = root.optionalScalar(cpuTemperatureFile, 1000);
        const cpuWatts = root.optionalScalar(root.cpuPowerFile, 1000000);

        root.snapshotState = Object.freeze({
            cpu: cpuPercent === null && cpuTemperature === null && cpuWatts === null ? null : Object.freeze({
                percent: cpuPercent,
                temperatureC: cpuTemperature,
                watts: cpuWatts,
                severity: SystemMonitorRules.severity(cpuPercent, cpuTemperature)
            }),
            gpu: gpuPercent === null && gpuTemperature === null && gpuWatts === null
                ? null : Object.freeze({
                    percent: gpuPercent,
                    temperatureC: gpuTemperature,
                    watts: gpuWatts,
                    severity: SystemMonitorRules.severity(gpuPercent, gpuTemperature)
                }),
            ram: memory,
            vram: vram,
            disk: root.snapshotState.disk,
            network: network
        });
        root.hotSampleAtState = now;
        root.liveState = root.active && cpuPercent !== null
            && memory !== null && network !== null
            && now >= root.activationStartedAt;
    }

    function startProcessSamples(): void {
        if (!root.psProcess.running) {
            root.psGeneration = root.generation;
            root.psProcess.running = true;
        }
    }

    function startDiskSample(): void {
        if (!root.dfProcess.running) {
            root.dfGeneration = root.generation;
            root.dfProcess.running = true;
        }
    }

    function refreshDue(now: double): void {
        if (!root.active)
            return;
        if (now >= root.nextHotAt) {
            root.sampleHot(now);
            root.nextHotAt = now + 2000;
        }
        if (now >= root.nextProcessAt) {
            root.startProcessSamples();
            root.nextProcessAt = now + 5000;
        }
        if (now >= root.nextDiskAt) {
            root.startDiskSample();
            root.nextDiskAt = now + 10000;
        }
        root.processesStaleState = root.processSampleAt <= 0
            || now - root.processSampleAt > 10000;
        root.schedule(now);
    }

    function schedule(now: double): void {
        if (!root.active)
            return;
        const nextAt = Math.min(root.nextHotAt, root.nextProcessAt, root.nextDiskAt);
        root.scheduler.interval = Math.max(50, Math.round(nextAt - now));
        root.scheduler.restart();
    }

    function start(): bool {
        if (root.active)
            return false;
        const now = Date.now();
        root.generation++;
        root.activeState = true;
        root.liveState = false;
        root.activationStartedAt = now;
        root.previousCpu = null;
        root.previousNetwork = null;
        root.previousNetworkAt = 0;
        root.nextHotAt = now;
        root.nextProcessAt = now;
        root.nextDiskAt = now;
        root.discoveryGeneration = root.generation;
        root.discoveryProcess.running = true;
        root.refreshDue(now);
        return true;
    }

    function stop(): bool {
        if (!root.active)
            return false;
        root.activeState = false;
        root.liveState = false;
        root.generation++;
        root.scheduler.stop();
        root.psProcess.running = false;
        root.dfProcess.running = false;
        root.discoveryProcess.running = false;
        return true;
    }

    function state(): string {
        return JSON.stringify({
            active: root.active,
            live: root.live,
            hotSampleAt: root.hotSampleAt,
            processSampleAt: root.processSampleAt,
            diskSampleAt: root.diskSampleAt,
            psRunning: root.psProcess.running,
            dfRunning: root.dfProcess.running,
            discoveryRunning: root.discoveryProcess.running,
            snapshot: root.snapshot,
            processCount: root.processes.length,
            processesStale: root.processesStale
        });
    }

    property Timer scheduler: Timer {
        repeat: false
        onTriggered: root.refreshDue(Date.now())
    }

    property Process discoveryProcess: Process {
        command: ["find", "-L", "/sys/class/drm", "/sys/class/hwmon", "/sys/class/powercap",
            "-maxdepth", "5", "-type", "f", "(",
            "(", "-name", "name", "-exec", "grep", "-l", "-E",
            "^(k10temp|zenpower)$", "{}", "+", ")", "-o", "(", "(",
            "-name", "gpu_busy_percent", "-o", "-name", "mem_info_vram_used", "-o",
            "-name", "mem_info_vram_total", "-o", "-name", "temp1_input", "-o",
            "-name", "power1_average", ")", "-print", ")", ")"]
        stdout: StdioCollector { id: discoveryOutput }
        stderr: StdioCollector {}
        onExited: {
            if (!root.active || root.discoveryGeneration !== root.generation)
                return;
            root.sensorPaths = SystemMonitorRules.selectSensorPaths(
                discoveryOutput.text.split(/\r?\n/));
        }
    }

    property Process psProcess: Process {
        command: ["ps", "-eo", "pid=,comm=,%cpu=,rss="]
        stdout: StdioCollector { id: psOutput }
        stderr: StdioCollector {}
        onExited: {
            if (!root.active || root.psGeneration !== root.generation)
                return;
            root.processesState = SystemMonitorRules.parseProcesses(psOutput.text);
            root.processSampleAt = Date.now();
            root.processesStaleState = false;
        }
    }

    property Process dfProcess: Process {
        command: ["df", "-P", "-B1", "/"]
        stdout: StdioCollector { id: dfOutput }
        stderr: StdioCollector {}
        onExited: {
            if (!root.active || root.dfGeneration !== root.generation)
                return;
            const disk = SystemMonitorRules.parseDf(dfOutput.text);
            if (disk === null)
                root.warn("disk", "could not parse root filesystem usage");
            root.snapshotState = Object.freeze({
                cpu: root.snapshotState.cpu,
                gpu: root.snapshotState.gpu,
                ram: root.snapshotState.ram,
                vram: root.snapshotState.vram,
                disk: disk,
                network: root.snapshotState.network
            });
            root.diskSampleAt = Date.now();
        }
    }

    property FileView cpuStatFile: FileView {
        path: "/proc/stat"; preload: false; blockLoading: true; printErrors: false
    }
    property FileView meminfoFile: FileView {
        path: "/proc/meminfo"; preload: false; blockLoading: true; printErrors: false
    }
    property FileView netDevFile: FileView {
        path: "/proc/net/dev"; preload: false; blockLoading: true; printErrors: false
    }
    property FileView gpuBusyFile: FileView {
        path: root.sensorPaths.gpuBusy || ""; preload: false; blockLoading: true; printErrors: false
    }
    property FileView vramUsedFile: FileView {
        path: root.sensorPaths.vramUsed || ""; preload: false; blockLoading: true; printErrors: false
    }
    property FileView vramTotalFile: FileView {
        path: root.sensorPaths.vramTotal || ""; preload: false; blockLoading: true; printErrors: false
    }
    property FileView gpuTemperatureFile: FileView {
        path: root.sensorPaths.gpuTemperature || ""; preload: false; blockLoading: true; printErrors: false
    }
    property FileView gpuPowerFile: FileView {
        path: root.sensorPaths.gpuPower || ""; preload: false; blockLoading: true; printErrors: false
    }
    property FileView cpuTemperatureFile: FileView {
        path: root.sensorPaths.cpuTemperature || ""; preload: false; blockLoading: true; printErrors: false
    }
    property FileView cpuPowerFile: FileView {
        path: root.sensorPaths.cpuPower || ""; preload: false; blockLoading: true; printErrors: false
    }
}
