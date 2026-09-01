#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "SystemMonitor",
    "SystemMonitorRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Services/SystemMonitor/SystemMonitorRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({ Math, Number, Object, Array, String, isFinite });
vm.runInContext(source, rules, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

const firstCpu = rules.parseCpuStat("cpu  100 20 30 400 10 5 3 2 0 0\n");
const nextCpu = rules.parseCpuStat("cpu  130 20 40 450 10 5 3 2 0 0\n");
assert.deepEqual(plain(firstCpu), { total: 570, idle: 410 });
assert.equal(rules.cpuPercent(firstCpu, nextCpu), 44.44444444444444);
assert.equal(rules.cpuPercent(null, nextCpu), null);
assert.equal(rules.cpuPercent(nextCpu, firstCpu), null);
assert.equal(rules.parseCpuStat("cpu broken"), null);
assert.equal(Object.isFrozen(firstCpu), true);
console.log("PASS system monitor CPU aggregate and guarded deltas");

const memory = rules.parseMeminfo(
    "MemTotal: 32768000 kB\nMemFree: 1000000 kB\nMemAvailable: 14000000 kB\n");
assert.deepEqual(plain(memory), {
    totalBytes: 33554432000,
    usedBytes: 19218432000,
    percent: 57.275390625,
});
assert.equal(rules.parseMeminfo("MemTotal: 10 kB\nMemFree: 2 kB\n"), null);
assert.equal(Object.isFrozen(memory), true);
console.log("PASS system monitor memory derives usage from MemAvailable");

assert.equal(rules.parseCpuName("processor: 0\nmodel name : AMD Ryzen 9 9900X3D 12-Core Processor\n"),
    "AMD Ryzen 9 9900X3D 12-Core Processor");
assert.equal(rules.parseCpuName("processor: 0\n"), null);
assert.equal(rules.parseAverageCpuFrequencyGhz(
    "processor: 0\ncpu MHz : 800.000\nprocessor: 1\ncpu MHz : 4200.000\n"), 2.5);
assert.equal(rules.parseAverageCpuFrequencyGhz("processor: 0\n"), null);
assert.equal(rules.parseGpuClock("0: 500Mhz\n1: 1600Mhz *\n2: 2660Mhz\n"), 1600);
assert.equal(rules.parseGpuClock("0: 500Mhz\n"), null);
assert.equal(rules.parseGpuName('03:00.0 "VGA compatible controller" "AMD" "Navi 21" -r "AMD" "Radeon RX 6900 XT"\n'),
    "Radeon RX 6900 XT");
assert.equal(rules.parseGpuName(""), null);
console.log("PASS system monitor hardware names and CPU/GPU clock parsing");

assert.equal(rules.scalar("54000\n", 1000), 54);
assert.equal(rules.scalar("bad", 1000), null);
assert.equal(rules.scalar("4", 0), null);
assert.equal(rules.powerFromEnergy(1000000, 3000000, 2000, 0), 1);
assert.equal(rules.powerFromEnergy(9000000, 1000000, 2000, 10000000), 1);
assert.equal(rules.powerFromEnergy(3, 2, 0, 10), null);
assert.deepEqual(plain(rules.capacity(612, 1000)), {
    usedBytes: 612,
    totalBytes: 1000,
    percent: 61.199999999999996,
});
assert.equal(rules.capacity(20, 0), null);
assert.equal(Object.isFrozen(rules.capacity(612, 1000)), true);
assert.deepEqual(plain(rules.parseStorageCapacity("1B-blocks Used\n1000 612\n")), {
    usedBytes: 612,
    totalBytes: 1000,
    percent: 61.199999999999996,
});
assert.equal(rules.parseStorageCapacity("1B-blocks Used\nbroken\n"), null);
console.log("PASS system monitor scalar, energy and capacity normalization");

const processes = rules.parseProcesses(
    "22 Firefox 12.5 1800000\n" +
    "24 firefox 2.5 200000\n" +
    "60 chrome 3.0 100000\n" +
    "61 chrome 4.0 200000\n" +
    "9 ChatGPT 4.0 820000\n" +
    "7 Hyprland 4.0 310000\n" +
    "31 malformed value no\n" +
    "30 Code 2.0 690000\n" +
    "40 Quickshell 1.0 180000\n" +
    "50 Sixth 0.5 1000\n");
assert.deepEqual(plain(processes), [
    { pid: 22, name: "Firefox", cpuPercent: 15, rssBytes: 2048000000, processCount: 2 },
    { pid: 60, name: "chrome", cpuPercent: 7, rssBytes: 307200000, processCount: 2 },
    { pid: 7, name: "Hyprland", cpuPercent: 4, rssBytes: 317440000, processCount: 1 },
    { pid: 9, name: "ChatGPT", cpuPercent: 4, rssBytes: 839680000, processCount: 1 },
    { pid: 30, name: "Code", cpuPercent: 2, rssBytes: 706560000, processCount: 1 },
]);
assert.equal(Object.isFrozen(processes), true);
assert.equal(Object.isFrozen(processes[0]), true);
console.log("PASS system monitor app-grouped top-five process parsing");

assert.equal(rules.severity(69, null), "neutral");
assert.equal(rules.severity(70, null), "warning");
assert.equal(rules.severity(90, null), "critical");
assert.equal(rules.severity(20, 80), "warning");
assert.equal(rules.severity(20, 90), "critical");
assert.equal(rules.severity(null, null), "neutral");
console.log("PASS system monitor severity uses capacity and temperature thresholds");

const selectedPaths = rules.selectSensorPaths([
    "/tmp/not-sys/gpu_busy_percent",
    "/sys/class/drm/card1/device/gpu_busy_percent",
    "/sys/class/drm/card1/device/mem_info_vram_used",
    "/sys/class/drm/card1/device/mem_info_vram_total",
    "/sys/class/drm/card1/device/pp_dpm_sclk",
    "/sys/class/drm/card1/device/hwmon/hwmon8/temp1_input",
    "/sys/class/drm/card2/device/gpu_busy_percent",
    "/sys/class/hwmon/hwmon0/temp1_input",
    "/sys/class/hwmon/hwmon3/name",
    "/sys/class/hwmon/hwmon3/temp1_input",
]);
assert.deepEqual(plain(selectedPaths), {
    gpuBusy: "/sys/class/drm/card1/device/gpu_busy_percent",
    vramUsed: "/sys/class/drm/card1/device/mem_info_vram_used",
    vramTotal: "/sys/class/drm/card1/device/mem_info_vram_total",
    gpuClock: "/sys/class/drm/card1/device/pp_dpm_sclk",
    gpuTemperature: "/sys/class/drm/card1/device/hwmon/hwmon8/temp1_input",
    cpuTemperature: "/sys/class/hwmon/hwmon3/temp1_input",
});
assert.equal(Object.isFrozen(selectedPaths), true);
console.log("PASS system monitor sensor paths select one complete DRM group without fixed index");
