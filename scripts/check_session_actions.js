#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const lifecyclePath = path.join(
    __dirname,
    "..",
    "Titonium/Platform/System/SessionActionLifecycle.js",
);

if (!fs.existsSync(lifecyclePath)) {
    console.error("FAIL session lifecycle helper is missing");
    process.exit(1);
}

const context = vm.createContext({});
const source = fs.readFileSync(lifecyclePath, "utf8").replace(/^\.pragma library\s*/, "");
vm.runInContext(source, context, { filename: lifecyclePath });

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

let transition = context.started(context.begin("restart"));
assert.deepEqual(plain(transition), {
    state: { action: "restart", kind: "short", phase: "running" },
    effect: "none",
    action: "",
    error: "",
}, "Process.started must preserve a short action without reporting success");

transition = context.exited(transition.state, 0);
assert.deepEqual(plain(transition), {
    state: { action: "", kind: "", phase: "idle" },
    effect: "accepted",
    action: "restart",
    error: "",
}, "a short session command succeeds only after exit 0");

transition = context.exited(context.started(context.begin("sleep")).state, 1);
assert.deepEqual(plain(transition), {
    state: { action: "", kind: "", phase: "idle" },
    effect: "failed",
    action: "sleep",
    error: "session.error.command_failed",
}, "a non-zero short command exit reports failure for the preserved action");

transition = context.stopped(context.begin("hibernate"));
assert.equal(transition.effect, "failed", "a process that never starts reports failure");
assert.equal(transition.action, "hibernate", "start failure retains the requested action");
assert.equal(transition.error, "session.error.start_failed", "start failure has a distinct error");

transition = context.started(context.begin("lock"));
assert.equal(transition.state.phase, "settling", "hyprlock enters its bounded startup-settle phase");
assert.equal(transition.effect, "none", "hyprlock start alone is not accepted");

const earlyLockFailure = context.exited(transition.state, 1);
assert.equal(earlyLockFailure.effect, "failed", "hyprlock non-zero exit before settle is failure");
assert.equal(earlyLockFailure.action, "lock", "early hyprlock failure retains the action");

const acceptedLock = context.settled(transition.state);
assert.equal(acceptedLock.effect, "accepted", "living through the one-shot gate accepts hyprlock startup");
assert.equal(acceptedLock.state.phase, "accepted", "accepted lock state survives until normal unlock exit");

const unlocked = context.exited(acceptedLock.state, 1);
assert.deepEqual(plain(unlocked), {
    state: { action: "", kind: "", phase: "idle" },
    effect: "none",
    action: "",
    error: "",
}, "normal exit after accepted lock startup is never reported as failure");

const quickLock = context.exited(transition.state, 0);
assert.equal(quickLock.effect, "accepted", "hyprlock exit 0 before settle is accepted completion");

console.log("PASS session action lifecycle fakes (9)");
