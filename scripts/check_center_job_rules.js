#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Center", "CenterJobRules.js");

assert.equal(fs.existsSync(rulesPath), true,
    "CenterJobRules.js must exist for explicit external jobs");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

const initial = rules.initialState();
const started = rules.start(initial, "build", " Build Titonium ", "important", 1000);
assert.equal(started.error, "");
assert.deepEqual(plain(started.next), [{
    id: "build",
    label: "Build Titonium",
    importance: "important",
    status: "running",
    percent: 0,
    changedAt: 1000,
}]);
assert.deepEqual(plain(started.event), {
    id: "job:build",
    deduplicationKey: "job:build",
    source: "job",
    kind: "job_started",
    title: "Build Titonium",
    icon: "work",
    importance: "important",
    createdAt: 1000,
});
assert.equal(Object.isFrozen(started.next), true);
assert.equal(Object.isFrozen(started.next[0]), true);
console.log("PASS job start normalizes a frozen active descriptor and semantic event");

const progressed = rules.progress(started.next, "build", 42.5, "Compiling", 2000);
assert.equal(progressed.error, "");
assert.equal(progressed.event, null);
assert.deepEqual(plain(progressed.next[0]), {
    id: "build",
    label: "Compiling",
    importance: "important",
    status: "running",
    percent: 42.5,
    changedAt: 2000,
});
console.log("PASS progress updates active state without replacing Center text");

let simultaneous = rules.start(progressed.next, "download", "ISO download", "normal", 2100);
assert.equal(simultaneous.error, "");
assert.deepEqual(plain(simultaneous.next.map(job => job.id)), ["build", "download"]);
assert.equal(simultaneous.next[1].importance, "normal");
console.log("PASS multiple jobs remain sorted and importance is allowlisted");

const completed = rules.complete(simultaneous.next, "build", "Build complete", 3000);
assert.equal(completed.error, "");
assert.deepEqual(plain(completed.next.map(job => job.id)), ["download"]);
assert.deepEqual(plain(completed.event), {
    id: "job:build",
    deduplicationKey: "job:build",
    source: "job",
    kind: "job_completed",
    title: "Build complete",
    icon: "check_circle",
    importance: "important",
    createdAt: 3000,
});
console.log("PASS completion removes only its job and preserves importance");

const failed = rules.fail(simultaneous.next, "download", "Download failed", 4000);
assert.equal(failed.error, "");
assert.equal(failed.next.length, 1);
assert.equal(failed.next[0].id, "build");
assert.equal(failed.event.kind, "job_failed");
assert.equal(failed.event.icon, "error");
assert.equal(failed.event.importance, "normal");
console.log("PASS failure removes only its job and emits an actionable event");

const requiresAction = rules.requireAction(
    simultaneous.next, "download", "Choose a mirror", 5000);
assert.equal(requiresAction.error, "");
assert.equal(requiresAction.next.length, 2);
assert.equal(requiresAction.next[1].status, "requires_action");
assert.equal(requiresAction.next[1].label, "Choose a mirror");
assert.equal(requiresAction.event.kind, "job_requires_action");
assert.equal(requiresAction.event.icon, "priority_high");
console.log("PASS requires-action remains active until explicitly cleared");

const cleared = rules.clear(requiresAction.next, "download");
assert.equal(cleared.error, "");
assert.deepEqual(plain(cleared.next.map(job => job.id)), ["build"]);
assert.equal(cleared.event, null);
console.log("PASS clear removes exactly one active job");

for (const result of [
    rules.start(initial, "", "Build", "normal", 0),
    rules.start(initial, "build", "", "normal", 0),
    rules.start(initial, "build", "Build", "urgent", 0),
    rules.start(started.next, "build", "Duplicate", "normal", 0),
    rules.progress(initial, "missing", 10, "Work", 0),
    rules.progress(started.next, "build", -1, "Work", 0),
    rules.progress(started.next, "build", 101, "Work", 0),
    rules.progress(started.next, "build", "   ", "Work", 0),
    rules.progress(started.next, "build", "0x10", "Work", 0),
    rules.progress(started.next, "build", 10, "", 0),
    rules.complete(initial, "missing", "Done", 0),
    rules.fail(initial, "missing", "Failed", 0),
    rules.requireAction(initial, "missing", "Act", 0),
    rules.clear(initial, "missing"),
]) {
    assert.match(result.error, /^error:/);
    assert.strictEqual(result.next, result.next === initial ? initial : started.next);
    assert.equal(result.event, null);
}
assert.equal(rules.progress(requiresAction.next, "download", 50, "Retrying", 0).error,
    "error:invalid_transition");
console.log("PASS malformed input, unknown IDs and invalid transitions fail closed");

let exactIds = rules.start(initial, "job one", "Single", "normal", 0);
exactIds = rules.start(exactIds.next, "job  one", "Double", "normal", 0);
assert.deepEqual(plain(exactIds.next.map(job => job.id)), ["job  one", "job one"]);
console.log("PASS job IDs preserve internal whitespace for exact lifecycle operations");
