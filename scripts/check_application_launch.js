#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const launchPath = path.join(
    __dirname,
    "..",
    "Titonium/Platform/Applications/ApplicationLaunch.js",
);

if (!fs.existsSync(launchPath)) {
    console.error("FAIL application launch helper is missing");
    process.exit(1);
}

const context = vm.createContext({ String });
const source = fs.readFileSync(launchPath, "utf8").replace(/^\.pragma library\s*/, "");
vm.runInContext(source, context, { filename: launchPath });

let executions = 0;
const accepted = context.request({ execute() { executions++; } });
assert.deepEqual(JSON.parse(JSON.stringify(accepted)), {
    accepted: true,
    error: "",
    detail: "",
}, "a synchronous DesktopEntry execution request is accepted exactly once");
assert.equal(executions, 1, "the injected desktop entry executes exactly once");

const missing = context.request(null);
assert.deepEqual(JSON.parse(JSON.stringify(missing)), {
    accepted: false,
    error: "application.error.unavailable",
    detail: "",
}, "a disappearing desktop entry is rejected without execution");

const thrown = context.request({
    execute() { throw new Error("fake launch rejection"); },
});
assert.equal(thrown.accepted, false, "a thrown DesktopEntry.execute request is rejected");
assert.equal(thrown.error, "application.error.launch_failed", "the thrown path has a stable Platform error");
assert.match(thrown.detail, /fake launch rejection/, "the thrown detail is retained for logging");

console.log("PASS application launch injection fakes (6)");
