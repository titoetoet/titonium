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
