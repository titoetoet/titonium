#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const helperPath = path.join(__dirname, "..", "Titonium", "Bar", "notch", "CenterActionCatalog.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL Center action catalog is missing");
    process.exit(1);
}

const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: helperPath });
const plain = value => JSON.parse(JSON.stringify(value));

const expectedTools = [
    "screenshot", "screen-recording", "color-picker", "ocr", "qr-scan",
    "camera-mirror", "night-mode", "more-tools",
];
const expectedSession = ["lock", "logout", "sleep", "hibernate", "restart", "shutdown"];
const tools = plain(context.tools());
const session = plain(context.session());
const actions = [...tools, ...session];

assert.deepEqual(tools.map(action => action.id), expectedTools, "Tools order is stable");
assert.deepEqual(session.map(action => action.id), expectedSession, "Session order is stable");
assert.equal(new Set(actions.map(action => action.id)).size, actions.length, "action IDs are unique");

for (const action of actions) {
    assert.match(action.labelKey, /^center_notch\.action\.[a-z0-9-]+$/, `${action.id} label is namespaced`);
    assert.equal(action.available, false, `${action.id} remains a safe mock`);
    assert.equal(typeof action.dangerous, "boolean", `${action.id} declares danger semantics`);
    assert.equal(typeof action.intent, "string", `${action.id} declares a future intent`);
    for (const forbidden of ["command", "callback", "process", "script", "executable"])
        assert.equal(Object.hasOwn(action, forbidden), false, `${action.id} has no ${forbidden}`);
}

assert.notStrictEqual(context.tools(), context.tools(), "Tools returns a fresh array");
assert.notStrictEqual(context.session(), context.session(), "Session returns a fresh array");

console.log("PASS Center action catalog fixtures (75)");
