#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Center", "CenterTimerRules.js");

assert.equal(fs.existsSync(rulesPath), true,
    "CenterTimerRules.js must exist for event-driven countdowns");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

const initial = rules.initialState();
const tenMinutes = rules.start(initial, "tea", 600, " Tea break ", 1000);
assert.deepEqual(plain(tenMinutes), [{
    id: "tea",
    label: "Tea break",
    deadline: 601000,
    fiveMinutePending: true,
    oneMinutePending: true,
}]);
assert.equal(Object.isFrozen(tenMinutes), true);
assert.equal(Object.isFrozen(tenMinutes[0]), true);
assert.deepEqual(plain(rules.nextWake(tenMinutes, 1000)), {
    at: 301000,
    delay: 300000,
});
console.log("PASS timer start stores a frozen absolute deadline and next milestone");

const fiveMinuteWake = rules.advance(tenMinutes, 301000);
assert.deepEqual(plain(fiveMinuteWake.events), [{
    id: "timer:tea",
    deduplicationKey: "timer:tea",
    source: "timer",
    kind: "timer_five_minutes",
    label: "Tea break",
    icon: "timer",
    createdAt: 301000,
}]);
assert.equal(fiveMinuteWake.next[0].fiveMinutePending, false);
assert.equal(fiveMinuteWake.next[0].oneMinutePending, true);
assert.deepEqual(plain(rules.nextWake(fiveMinuteWake.next, 301000)), {
    at: 541000,
    delay: 240000,
});
console.log("PASS five-minute milestone fires once and schedules one minute");

const shortTimer = rules.start(rules.initialState(), "stretch", 120, "Stretch", 1000);
assert.equal(shortTimer[0].fiveMinutePending, false);
assert.equal(shortTimer[0].oneMinutePending, true);
assert.deepEqual(plain(rules.nextWake(shortTimer, 1000)), {
    at: 61000,
    delay: 60000,
});
const veryShortTimer = rules.start(rules.initialState(), "eyes", 30, "Rest eyes", 1000);
assert.equal(veryShortTimer[0].fiveMinutePending, false);
assert.equal(veryShortTimer[0].oneMinutePending, false);
assert.deepEqual(plain(rules.nextWake(veryShortTimer, 1000)), {
    at: 31000,
    delay: 30000,
});
console.log("PASS timers below a threshold schedule only future milestones");

let simultaneous = rules.start(rules.initialState(), "tea", 120, "Tea", 1000);
simultaneous = rules.start(simultaneous, "build", 30, "Build", 1000);
assert.equal(rules.nextWake(simultaneous, 1000).at, 31000);
const firstFinished = rules.advance(simultaneous, 31000);
assert.deepEqual(plain(firstFinished.events), [{
    id: "timer:build",
    deduplicationKey: "timer:build",
    source: "timer",
    kind: "timer_finished",
    label: "Build",
    icon: "timer",
    createdAt: 31000,
}]);
assert.deepEqual(plain(firstFinished.next.map(timer => timer.id)), ["tea"]);
console.log("PASS simultaneous timers wake at the nearest milestone");

const cancelled = rules.cancel(simultaneous, "build");
assert.deepEqual(plain(cancelled.map(timer => timer.id)), ["tea"]);
assert.strictEqual(rules.cancel(cancelled, "missing"), cancelled);
assert.strictEqual(rules.start(cancelled, "", 10, "Invalid", 0), cancelled);
assert.strictEqual(rules.start(cancelled, "bad", 0, "Invalid", 0), cancelled);
assert.strictEqual(rules.start(cancelled, "bad", 10, "   ", 0), cancelled);
console.log("PASS cancellation is exact and malformed starts fail closed");

let exactIds = rules.start(rules.initialState(), "foo bar", 10, "Single", 0);
exactIds = rules.start(exactIds, "foo  bar", 20, "Double", 0);
assert.deepEqual(plain(exactIds.map(timer => timer.id)), ["foo  bar", "foo bar"]);
assert.deepEqual(
    plain(rules.cancel(exactIds, "foo  bar").map(timer => timer.id)),
    ["foo bar"]
);
console.log("PASS timer IDs preserve internal whitespace for exact cancellation");

const overdue = rules.advance(veryShortTimer, 90000);
assert.equal(overdue.next.length, 0);
assert.equal(overdue.events.length, 1);
assert.equal(overdue.events[0].kind, "timer_finished");
assert.equal(overdue.events[0].createdAt, 31000);
const alreadyRemoved = rules.advance(overdue.next, 100000);
assert.equal(alreadyRemoved.events.length, 0);
assert.equal(rules.nextWake(alreadyRemoved.next, 100000), null);
console.log("PASS overdue completion fires once before timer removal");

let delayed = rules.start(rules.initialState(), "z-old", 30, "Older", 0);
delayed = rules.start(delayed, "a-new", 40, "Newer", 0);
const delayedWake = rules.advance(delayed, 50000);
assert.deepEqual(plain(delayedWake.events.map(event => ({
    id: event.id,
    createdAt: event.createdAt,
}))), [
    { id: "timer:z-old", createdAt: 30000 },
    { id: "timer:a-new", createdAt: 40000 },
]);
console.log("PASS delayed wakes publish due milestones in scheduled-time order");
