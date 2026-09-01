#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Bar", "islands",
    "CenterActivationRules.js");
if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing CenterActivationRules.js");
    process.exit(1);
}
const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

assert.equal(rules.intent("media"), "raise-media");
assert.equal(rules.intent("clipboard"), "open-clipboard");
assert.equal(rules.intent("notification"), "open-center");
assert.equal(rules.intent("timer"), "open-center");
assert.equal(rules.intent(""), "open-center");
console.log("PASS Center activation routes source actions and preserves popup fallback");
