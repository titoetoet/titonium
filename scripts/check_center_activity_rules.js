#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Center",
    "CenterActivityRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Services/Center/CenterActivityRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

function job(id, importance, progress, updatedAt, label) {
    return {
        id: id,
        source: "job",
        label: label || id,
        icon: "work",
        importance: importance,
        progress: progress,
        deadline: 0,
        updatedAt: updatedAt,
    };
}

function timer(id, deadline, updatedAt, label) {
    return {
        id: id,
        source: "timer",
        label: label || id,
        icon: "timer",
        importance: "normal",
        progress: -1,
        deadline: deadline,
        updatedAt: updatedAt,
    };
}

let state = rules.initialState();
assert.deepEqual(plain(state), {
    activities: [], currentId: "", showingFocus: true, generation: 0,
});

state = rules.upsert(state, {
    id: " job:build ", source: "job", label: " Build   Titonium ",
    icon: "work", importance: "important", progress: 62,
    deadline: 0, updatedAt: 1000,
}, 1000);
assert.deepEqual(plain(state.activities[0]), {
    id: "job:build", source: "job", label: "Build Titonium",
    icon: "work", importance: "important", progress: 62,
    deadline: 0, updatedAt: 1000,
});
assert.equal(Object.isFrozen(state), true);
assert.equal(Object.isFrozen(state.activities), true);
assert.equal(Object.isFrozen(state.activities[0]), true);
assert.equal(state.generation, 0);
console.log("PASS activity descriptors normalize into frozen value state");

const unchanged = state;
for (const invalid of [
    null,
    {},
    job("", "normal", 10, 1000, "Blank ID"),
    job("job:blank", "normal", 10, 1000, "   "),
    job("job:importance", "urgent", 10, 1000),
    job("job:low", "normal", -1, 1000),
    job("job:high", "normal", 101, 1000),
    { ...job("job:source", "normal", 10, 1000), source: "system" },
    timer("timer:past", 1000, 1000),
    { ...job("job:priority", "normal", 10, 1000), priority: 90 },
    { ...job("job:rank", "normal", 10, 1000), rank: 90 },
    { ...job("job:ttl", "normal", 10, 1000), ttl: 5000 },
    { ...job("job:command", "normal", 10, 1000), command: "make" },
    { ...job("job:callback", "normal", 10, 1000), callback: () => {} },
]) {
    assert.strictEqual(rules.upsert(unchanged, invalid, 2000), unchanged);
}
console.log("PASS malformed and policy-bearing activity inputs fail closed");

let bounded = rules.initialState();
for (let index = 0; index < 33; index++) {
    bounded = rules.upsert(bounded,
        job("job:" + index, "normal", index, index + 1), 1000);
}
assert.equal(bounded.activities.length, 32);
assert.equal(bounded.activities.some(item => item.id === "job:0"), false);
assert.equal(bounded.activities[0].id, "job:32");
console.log("PASS activity registry is bounded by derived rank and recency");

let rotation = rules.initialState();
rotation = rules.upsert(rotation, job("job:normal", "normal", 20, 1000), 1000);
rotation = rules.upsert(rotation,
    job("job:important", "important", 40, 2000), 2000);
rotation = rules.upsert(rotation,
    timer("timer:tea", 600000, 3000, "Tea"), 3000);
rotation = rules.upsert(rotation,
    job("job:hidden", "normal", 80, 500, "Hidden"), 3000);

assert.deepEqual(plain(rules.visiblePool(rotation)).map(item => item.id), [
    "timer:tea", "job:important", "job:normal",
]);
assert.equal(rules.current(rotation), null);
rotation = rules.advance(rotation);
assert.equal(rules.current(rotation).id, "timer:tea");
rotation = rules.advance(rotation);
assert.equal(rules.current(rotation).id, "job:important");
rotation = rules.advance(rotation);
assert.equal(rules.current(rotation).id, "job:normal");
rotation = rules.advance(rotation);
assert.equal(rules.current(rotation), null);
assert.equal(rotation.showingFocus, true);
assert.equal(rotation.generation, 4);
console.log("PASS rotation presents Focus then the top three ranked activities");

rotation = rules.advance(rotation);
assert.equal(rules.current(rotation).id, "timer:tea");
const timerGeneration = rotation.generation;
rotation = rules.upsert(rotation,
    timer("timer:tea", 660000, 4000, "Green tea"), 4000);
assert.equal(rotation.currentId, "timer:tea");
assert.equal(rotation.showingFocus, false);
assert.equal(rotation.generation, timerGeneration + 1);
assert.equal(rules.current(rotation).label, "Green tea");

const beforeNonCurrentRemoval = rotation;
rotation = rules.remove(rotation, "job:hidden");
assert.equal(rotation.currentId, "timer:tea");
assert.equal(rotation.generation, beforeNonCurrentRemoval.generation);
rotation = rules.remove(rotation, "timer:tea");
assert.equal(rotation.currentId, "");
assert.equal(rotation.showingFocus, true);
assert.equal(rotation.generation, timerGeneration + 2);
console.log("PASS updates preserve slots and visible removal returns to Focus");

const empty = rules.initialState();
assert.strictEqual(rules.remove(empty, "missing"), empty);
assert.strictEqual(rules.advance(empty), empty);
assert.equal(rules.remainingMinutes(61000, 1000), 1);
assert.equal(rules.remainingMinutes(61001, 1000), 2);
assert.equal(rules.remainingMinutes(1000, 1000), 0);
assert.equal(rules.remainingMinutes("bad", 1000), 0);
assert.equal(rules.remainingMinutes(1000, Number.NaN), 0);
console.log("PASS empty rotation is stable and remaining minutes are ceiling-bounded");
