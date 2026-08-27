#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Services", "WindowSwitcher",
    "WindowSwitcherRules.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Window Switcher rules are missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: helperPath });
const rules = context;
const plain = value => JSON.parse(JSON.stringify(value));

const windows = [
    { id: "one", appId: "one.app", title: "One", icon: "one", active: false,
        urgent: false, minimized: false },
    { id: "two", appId: "two.app", title: "Two", icon: "two", active: true,
        urgent: false, minimized: false },
    { id: "three", appId: "three.app", title: "Three", icon: "three", active: false,
        urgent: true, minimized: true },
    { id: "four", appId: "four.app", title: "Four", icon: "four", active: false,
        urgent: false, minimized: false },
];

const mru = rules.mruIds(["four", "one", "three", "gone"], windows);
assert.deepEqual(plain(mru), ["two", "four", "one"]);
const ordered = rules.orderedWindows(windows, mru);
assert.deepEqual(plain(ordered.map(window => window.id)), ["two", "four", "one"]);
assert.equal(ordered.some(window => window.minimized), false);
assert.equal(Object.isFrozen(ordered), true);
console.log("PASS Window Switcher minimized filtering and active-first MRU fixtures");

assert.equal(rules.beginSelection(ordered, "next"), "four");
assert.equal(rules.beginSelection(ordered, "previous"), "one");
assert.equal(rules.moveSelection(ordered, "one", 1), "two");
assert.equal(rules.moveSelection(ordered, "two", -1), "one");
assert.equal(rules.moveSelection(ordered, "four", 1), "one");
assert.equal(rules.moveSelection(ordered, "four", -1), "two");
console.log("PASS Window Switcher begin and wrap fixtures");

assert.equal(rules.reconcileSelection(ordered, "gone"), "two");
assert.equal(rules.reconcileSelection(ordered, "four"), "four");
assert.equal(rules.reconcileSelection([], "four"), "");
assert.equal(rules.beginSelection([], "next"), "");
assert.equal(rules.moveSelection([], "", 1), "");
console.log("PASS Window Switcher stale selection and empty close fixtures");
