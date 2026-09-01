pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Titonium.Core.Runtime
import "SystemMonitorRules.js" as SystemMonitorRules

QtObject {
    id: root

    property int generation: 0
    property int discoveryGeneration: 0
    property int psGeneration: 0
    property int gpuInfoGeneration: 0
    property int storageGeneration: 0
    property bool activeState: false
    property bool liveState: false
    property double activationStartedAt: 0
    property double hotSampleAtState: 0
    property double nextHotAt: 0
    property double nextProcessAt: 0
    property double nextHistoryAt: 0
    property double nextStorageAt: 0
    property double processSampleAt: 0
    property double storageSampleAt: 0
    property var snapshotState: Object.freeze({
        cpu: null, gpu: null, ram: null, vram: null, storage: null
    })
    property var processesState: Object.freeze([])
    property var cpuHistoryState: Object.freeze([])
    property var cpuTemperatureHistoryState: Object.freeze([])
    property var storageState: null
    property var previousCpu: null
    property var warningCounts: ({})
    property var sensorPaths: Object.freeze({})
    property string cpuNameState: ""
    property string gpuNameState: ""

    readonly property int hotSampleIntervalMs: 1000
    readonly property int processSampleIntervalMs: 2000
    readonly property int historySampleIntervalMs: 1000
    readonly property int storageSampleIntervalMs: 5000
    readonly property bool active: root.activeState
    readonly property bool live: root.liveState
    readonly property double hotSampleAt: root.hotSampleAtState
    readonly property var snapshot: root.snapshotState
    readonly property var processes: root.processesState
    readonly property var cpuHistory: root.cpuHistoryState
    readonly property var cpuTemperatureHistory: root.cpuTemperatureHistoryState

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
        const cpuFrequencyGhz = SystemMonitorRules.parseAverageCpuFrequencyGhz(
            root.readView(cpuInfoFile));

        const gpuPercent = root.optionalScalar(gpuBusyFile, 1);
        const vramUsed = root.optionalScalar(vramUsedFile, 1);
        const vramTotal = root.optionalScalar(vramTotalFile, 1);
        const vram = SystemMonitorRules.capacity(vramUsed, vramTotal);
        const gpuTemperature = root.optionalScalar(gpuTemperatureFile, 1000);
        const gpuClockMhz = SystemMonitorRules.parseGpuClock(root.readView(gpuClockFile));
        const cpuTemperature = root.optionalScalar(cpuTemperatureFile, 1000);

        if (now >= root.nextHistoryAt) {
            if (cpuPercent !== null) {
                root.cpuHistoryState = Object.freeze(
                    root.cpuHistoryState.concat([cpuPercent]).slice(-60));
            }
            if (cpuTemperature !== null) {
                root.cpuTemperatureHistoryState = Object.freeze(
                    root.cpuTemperatureHistoryState.concat([cpuTemperature]).slice(-60));
            }
            root.nextHistoryAt = now + root.historySampleIntervalMs;
        }

        root.snapshotState = Object.freeze({
            cpu: cpuPercent === null && cpuTemperature === null
                ? null : Object.freeze({
                    name: root.cpuNameState || null,
                    percent: cpuPercent,
                    frequencyGhz: cpuFrequencyGhz,
                    temperatureC: cpuTemperature,
                    severity: SystemMonitorRules.severity(cpuPercent, cpuTemperature)
                }),
            gpu: gpuPercent === null && gpuTemperature === null && gpuClockMhz === null
                ? null : Object.freeze({
                    name: root.gpuNameState || null,
                    percent: gpuPercent,
                    clockMhz: gpuClockMhz,
                    temperatureC: gpuTemperature,
                    severity: SystemMonitorRules.severity(gpuPercent, gpuTemperature)
                }),
            ram: memory,
            vram: vram,
            storage: root.storageState
        });
        root.hotSampleAtState = now;
        root.liveState = root.active && cpuPercent !== null
            && memory !== null
            && now >= root.activationStartedAt;
    }

    function startProcessSamples(): void {
        if (!root.psProcess.running) {
            root.psGeneration = root.generation;
            root.psProcess.running = true;
        }
    }

    function startStorageSample(): void {
        if (!root.storageProcess.running) {
            root.storageGeneration = root.generation;
            root.storageProcess.running = true;
        }
    }

    function refreshDue(now: double): void {
        if (!root.active)
            return;
        if (now >= root.nextHotAt) {
            root.sampleHot(now);
            root.nextHotAt = now + root.hotSampleIntervalMs;
        }
        if (now >= root.nextProcessAt) {
            root.startProcessSamples();
            root.nextProcessAt = now + root.processSampleIntervalMs;
        }
        if (now >= root.nextStorageAt) {
            root.startStorageSample();
            root.nextStorageAt = now + root.storageSampleIntervalMs;
        }
        root.schedule(now);
    }

    function schedule(now: double): void {
        if (!root.active)
            return;
        const nextAt = Math.min(root.nextHotAt, root.nextProcessAt, root.nextStorageAt);
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
        root.processSampleAt = 0;
        root.storageSampleAt = 0;
        root.processesState = Object.freeze([]);
        root.cpuHistoryState = Object.freeze([]);
        root.cpuTemperatureHistoryState = Object.freeze([]);
        root.storageState = null;
        root.sensorPaths = Object.freeze({});
        root.cpuNameState = SystemMonitorRules.parseCpuName(root.readView(cpuInfoFile)) || "";
        root.gpuNameState = "";
        root.nextHotAt = now;
        root.nextProcessAt = now;
        root.nextHistoryAt = now;
        root.nextStorageAt = now;
        root.discoveryGeneration = root.generation;
        root.gpuInfoGeneration = root.generation;
        root.discoveryProcess.running = true;
        root.gpuInfoProcess.running = true;
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
        root.discoveryProcess.running = false;
        root.gpuInfoProcess.running = false;
        root.storageProcess.running = false;
        root.snapshotState = Object.freeze({
            cpu: null, gpu: null, ram: null, vram: null, storage: null
        });
        root.processesState = Object.freeze([]);
        root.cpuHistoryState = Object.freeze([]);
        root.cpuTemperatureHistoryState = Object.freeze([]);
        root.storageState = null;
        root.previousCpu = null;
        root.sensorPaths = Object.freeze({});
        root.cpuNameState = "";
        root.gpuNameState = "";
        root.hotSampleAtState = 0;
        root.processSampleAt = 0;
        root.storageSampleAt = 0;
        return true;
    }

    function state(): string {
        return JSON.stringify({
            active: root.active,
            live: root.live,
            hotSampleAt: root.hotSampleAt,
            processSampleAt: root.processSampleAt,
            psRunning: root.psProcess.running,
            discoveryRunning: root.discoveryProcess.running,
            gpuInfoRunning: root.gpuInfoProcess.running,
            storageRunning: root.storageProcess.running,
            snapshot: root.snapshot,
            cpuHistory: root.cpuHistory,
            cpuTemperatureHistory: root.cpuTemperatureHistory,
            storageSampleAt: root.storageSampleAt,
            processCount: root.processes.length,
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
            "-name", "mem_info_vram_total", "-o", "-name", "pp_dpm_sclk", "-o",
            "-name", "temp1_input", ")", "-print", ")", ")"]
        stdout: StdioCollector { id: discoveryOutput }
        stderr: StdioCollector {}
        onExited: {
            if (!root.active || root.discoveryGeneration !== root.generation)
                return;
            root.sensorPaths = SystemMonitorRules.selectSensorPaths(
                discoveryOutput.text.split(/\r?\n/));
        }
    }

    property Process gpuInfoProcess: Process {
        command: ["lspci", "-mm", "-d", "::0300"]
        stdout: StdioCollector { id: gpuInfoOutput }
        stderr: StdioCollector {}
        onExited: {
            if (!root.active || root.gpuInfoGeneration !== root.generation)
                return;
            root.gpuNameState = SystemMonitorRules.parseGpuName(gpuInfoOutput.text) || "";
        }
    }

    property Process psProcess: Process {
        command: ["ps", "-eo", "pid=,comm=,%cpu=,rss="]
        stdout: StdioCollector { id: psOutput }
        stderr: StdioCollector {}
        onExited: {
            if (!root.active || root.psGeneration !== root.generation)
                return;
            if (psOutput.text.trim().length === 0) {
                root.warn("processes", "could not read process usage");
                return;
            }
            root.processesState = SystemMonitorRules.parseProcesses(psOutput.text);
            root.processSampleAt = Date.now();
        }
    }

    property Process storageProcess: Process {
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector { id: storageOutput }
        stderr: StdioCollector {}
        onExited: {
            if (!root.active || root.storageGeneration !== root.generation)
                return;
            const storage = SystemMonitorRules.parseStorageCapacity(storageOutput.text);
            if (!storage) {
                root.warn("storage", "could not read root filesystem capacity");
                return;
            }
            root.storageState = storage;
            root.storageSampleAt = Date.now();
            root.snapshotState = Object.freeze({
                cpu: root.snapshotState.cpu,
                gpu: root.snapshotState.gpu,
                ram: root.snapshotState.ram,
                vram: root.snapshotState.vram,
                storage: storage
            });
        }
    }

    property FileView cpuStatFile: FileView {
        path: "/proc/stat"; preload: false; blockLoading: true; printErrors: false
    }
    property FileView meminfoFile: FileView {
        path: "/proc/meminfo"; preload: false; blockLoading: true; printErrors: false
    }
    property FileView cpuInfoFile: FileView {
        path: "/proc/cpuinfo"; preload: false; blockLoading: true; printErrors: false
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
    property FileView gpuClockFile: FileView {
        path: root.sensorPaths.gpuClock || ""; preload: false; blockLoading: true; printErrors: false
    }
    property FileView cpuTemperatureFile: FileView {
        path: root.sensorPaths.cpuTemperature || ""; preload: false; blockLoading: true; printErrors: false
    }
}
