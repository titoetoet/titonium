#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");

function loadRules(relative) {
    const rulesPath = path.join(root, relative);
    const source = fs.readFileSync(rulesPath, "utf8")
        .replace(/^\.pragma library\s*\n/, "");
    const context = vm.createContext({ Object, String, Number });
    vm.runInContext(source, context, { filename: rulesPath });
    return context;
}

const arbiter = loadRules("Titonium/Core/Surfaces/FocusArbiterRules.js");
const plain = value => JSON.parse(JSON.stringify(value));

let state = arbiter.initial();
assert.deepEqual(plain(state), {
    owner: "", pendingOwner: "", generation: 0,
    phase: "idle", shouldSchedule: false, violation: "",
});
assert.equal(Object.isFrozen(state), true, "initial snapshots must be frozen");

state = arbiter.request(state, "edge-menu:DP-1");
assert.deepEqual(plain(state), {
    owner: "edge-menu:DP-1", pendingOwner: "", generation: 1,
    phase: "owned", shouldSchedule: false, violation: "",
});
assert.equal(Object.isFrozen(state), true, "granted snapshots must be frozen");

const sameOwner = arbiter.request(state, " edge-menu:DP-1 ");
assert.deepEqual(plain(sameOwner), plain(state),
    "a current-owner request is idempotent after owner normalization");

state = arbiter.request(state, "center:DP-1");
assert.equal(state.owner, "");
assert.equal(state.pendingOwner, "center:DP-1");
assert.equal(state.phase, "releasing");
assert.equal(state.shouldSchedule, true);
const centerGeneration = state.generation;

state = arbiter.request(state, "overlay:spotlight:DP-1");
assert.equal(state.owner, "");
assert.equal(state.pendingOwner, "overlay:spotlight:DP-1");
assert.equal(state.generation, centerGeneration + 1);
assert.equal(state.phase, "releasing");
assert.equal(state.shouldSchedule, true);
assert.equal(arbiter.grantPending(state, centerGeneration).owner, "",
    "a stale generation must not grant the replaced pending owner");
state = arbiter.grantPending(state, state.generation);
assert.equal(state.owner, "overlay:spotlight:DP-1");
assert.equal(state.pendingOwner, "");
assert.equal(state.phase, "owned");
assert.equal(state.shouldSchedule, false);

const staleRelease = arbiter.withdraw(state, "center:DP-1");
assert.equal(staleRelease.owner, "overlay:spotlight:DP-1",
    "a stale release cannot clear a newer owner");
assert.equal(arbiter.withdraw(state, "overlay:spotlight:DP-1").phase, "idle");

const blankRequest = arbiter.request(state, "  ");
assert.equal(blankRequest.owner, state.owner, "blank requests cannot replace an owner");
assert.equal(blankRequest.pendingOwner, state.pendingOwner);
assert.equal(blankRequest.generation, state.generation);
assert.equal(blankRequest.violation, "missing-focus-owner");
assert.equal(Object.isFrozen(blankRequest), true);

const blankWithdrawal = arbiter.withdraw(state, "\t");
assert.equal(blankWithdrawal.owner, state.owner, "blank withdrawals cannot release an owner");
assert.equal(blankWithdrawal.generation, state.generation);
assert.equal(blankWithdrawal.violation, "missing-focus-owner");

let replacement = arbiter.initial();
replacement = arbiter.request(replacement, "center:DP-1");
replacement = arbiter.request(replacement, "overlay:spotlight:DP-1");
const spotlightGeneration = replacement.generation;
replacement = arbiter.request(replacement, "settings:DP-1");
const settingsGeneration = replacement.generation;
assert.equal(replacement.pendingOwner, "settings:DP-1",
    "the newest pending request must replace Spotlight");
assert.equal(arbiter.grantPending(replacement, spotlightGeneration).owner, "",
    "Spotlight's stale generation cannot reclaim focus");
replacement = arbiter.grantPending(replacement, settingsGeneration);
assert.equal(replacement.owner, "settings:DP-1");
assert.equal(arbiter.withdraw(replacement, "overlay:spotlight:DP-1").owner,
    "settings:DP-1");
replacement = arbiter.withdraw(replacement, "settings:DP-1");
assert.deepEqual(plain(replacement), {
    owner: "", pendingOwner: "", generation: settingsGeneration,
    phase: "idle", shouldSchedule: false, violation: "",
});

let pending = arbiter.initial();
pending = arbiter.request(pending, "center:DP-1");
pending = arbiter.request(pending, "overlay:spotlight:DP-1");
pending = arbiter.withdraw(pending, "overlay:spotlight:DP-1");
assert.deepEqual(plain(pending), {
    owner: "", pendingOwner: "", generation: 2,
    phase: "idle", shouldSchedule: false, violation: "",
}, "withdrawing the pending owner cancels the handoff");
assert.equal(arbiter.grantPending(pending, 2).phase, "idle");

console.log("PASS exclusive focus arbiter state machine");
