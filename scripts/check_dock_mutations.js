#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Dock", "DockMutationRules.js");
const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({ Object, Array, String });
vm.runInContext(source, rules, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

assert.deepEqual(plain(rules.toggle(["firefox.desktop"], "chatgpt.desktop")), {
    accepted: true, persisted: false,
    value: ["firefox.desktop", "chatgpt.desktop"], error: ""
});
assert.deepEqual(plain(rules.toggle(["ChatGPT.desktop"], "chatgpt.desktop")), {
    accepted: true, persisted: false, value: [], error: ""
});
assert.deepEqual(plain(rules.toggle([], "   ")), {
    accepted: false, persisted: false, value: [], error: "invalid-app-id"
});
assert.deepEqual(plain(rules.withWriteResult(rules.toggle([], "chatgpt.desktop"), false,
    "preferences-busy")), {
    accepted: false, persisted: false, value: ["chatgpt.desktop"],
    error: "preferences-busy"
});
assert.deepEqual(plain(rules.withWriteResult(rules.toggle([], "chatgpt.desktop"), true, "")), {
    accepted: true, persisted: true, value: ["chatgpt.desktop"], error: ""
});
assert.deepEqual(plain(rules.visibility(true, true, "")), {
    accepted: true, persisted: true, value: true, error: ""
}, "the Dock reserve-space pin control must expose an observable successful mutation");
assert.deepEqual(plain(rules.visibility(false, false, "preferences-busy")), {
    accepted: false, persisted: false, value: false, error: "preferences-busy"
});

console.log("PASS Dock pin mutation result contract");
