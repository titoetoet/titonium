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

const netA = rules.parseNetDev(
    "Inter-| Receive | Transmit\n" +
    "lo: 99 0 0 0 0 0 0 0 99 0 0 0 0 0 0 0\n" +
    "enp1s0: 1000 0 0 0 0 0 0 0 2000 0 0 0 0 0 0 0\n");
const netB = rules.parseNetDev(
    "enp1s0: 5000 0 0 0 0 0 0 0 6000 0 0 0 0 0 0 0\n");
assert.deepEqual(plain(netA), { rxBytes: 1000, txBytes: 2000 });
assert.deepEqual(plain(rules.networkRate(netA, netB, 2000)), {
    downBps: 2000,
    upBps: 2000,
});
assert.equal(rules.networkRate(netB, netA, 2000), null);
assert.equal(rules.networkRate(netA, netB, 0), null);
assert.equal(rules.parseNetDev("lo: 1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0"), null);
assert.equal(Object.isFrozen(netA), true);
console.log("PASS system monitor network aggregates non-loopback guarded rates");

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
console.log("PASS system monitor scalar, energy and capacity normalization");

assert.deepEqual(plain(rules.parseDf(
    "Filesystem 1-blocks Used Available Use% Mounted on\n/dev/root 1000 612 388 62% /\n"
)), { usedBytes: 612, totalBytes: 1000, percent: 61.199999999999996 });
assert.equal(rules.parseDf("bad output"), null);

const processes = rules.parseProcesses(
    "22 Firefox 12.5 1800000\n" +
    "9 ChatGPT 4.0 820000\n" +
    "7 Hyprland 4.0 310000\n" +
    "31 malformed value no\n" +
    "30 Code 2.0 690000\n" +
    "40 Quickshell 1.0 180000\n" +
    "50 Sixth 0.5 1000\n");
assert.deepEqual(plain(processes), [
    { pid: 22, name: "Firefox", cpuPercent: 12.5, rssBytes: 1843200000 },
    { pid: 7, name: "Hyprland", cpuPercent: 4, rssBytes: 317440000 },
    { pid: 9, name: "ChatGPT", cpuPercent: 4, rssBytes: 839680000 },
    { pid: 30, name: "Code", cpuPercent: 2, rssBytes: 706560000 },
    { pid: 40, name: "Quickshell", cpuPercent: 1, rssBytes: 184320000 },
]);
assert.equal(Object.isFrozen(processes), true);
assert.equal(Object.isFrozen(processes[0]), true);
console.log("PASS system monitor disk and stable top-five process parsing");

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
    "/sys/class/drm/card1/device/hwmon/hwmon8/temp1_input",
    "/sys/class/drm/card1/device/hwmon/hwmon8/power1_average",
    "/sys/class/drm/card2/device/gpu_busy_percent",
    "/sys/class/hwmon/hwmon0/temp1_input",
    "/sys/class/hwmon/hwmon3/name",
    "/sys/class/hwmon/hwmon3/temp1_input",
    "/sys/class/hwmon/hwmon3/power1_average",
]);
assert.deepEqual(plain(selectedPaths), {
    gpuBusy: "/sys/class/drm/card1/device/gpu_busy_percent",
    vramUsed: "/sys/class/drm/card1/device/mem_info_vram_used",
    vramTotal: "/sys/class/drm/card1/device/mem_info_vram_total",
    gpuPower: "/sys/class/drm/card1/device/hwmon/hwmon8/power1_average",
    gpuTemperature: "/sys/class/drm/card1/device/hwmon/hwmon8/temp1_input",
    cpuTemperature: "/sys/class/hwmon/hwmon3/temp1_input",
    cpuPower: "/sys/class/hwmon/hwmon3/power1_average",
});
assert.equal(Object.isFrozen(selectedPaths), true);
console.log("PASS system monitor sensor paths select one complete DRM group without fixed index");
