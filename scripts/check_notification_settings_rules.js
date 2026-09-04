#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Settings", "NotificationSettingsRules.js");
assert.equal(fs.existsSync(rulesPath), true, "NotificationSettingsRules must exist");

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

const original = Object.freeze({ terminal: "critical" });
assert.deepEqual(plain(rules.setOverride(original, "browser", "quiet")), {
    terminal: "critical", browser: "quiet"
});
assert.deepEqual(plain(original), { terminal: "critical" }, "edits must not mutate preview state");
assert.deepEqual(plain(rules.setOverride(original, " browser ", "block")), {
    terminal: "critical", browser: "block"
});
assert.strictEqual(rules.setOverride(original, "", "quiet"), original);
assert.strictEqual(rules.setOverride(original, "browser", "loud"), original);
for (const unsafeId of ["__proto__", "prototype", "constructor"])
    assert.strictEqual(rules.setOverride(original, unsafeId, "block"), original);
assert.deepEqual(plain(rules.resetOverride({ browser: "quiet", terminal: "critical" },
    "browser")), { terminal: "critical" });
assert.deepEqual(plain(rules.resetOverride({ browser: "quiet" }, "missing")), {
    browser: "quiet"
});
assert.deepEqual(plain(rules.resetAll()), {});
assert.equal(rules.currentOverride({ browser: "block" }, "browser"), "block");
assert.equal(rules.currentOverride({ browser: "invalid" }, "browser"), "follow");

const rows = plain(rules.applicationRows([
    { id: "terminal", name: "Terminal", icon: "terminal" },
    { id: "browser", name: "Browser", icon: "browser" },
], { "org.extra.App": "quiet", terminal: "critical" }));
assert.deepEqual(rows, [
    { id: "browser", name: "Browser", icon: "browser" },
    { id: "org.extra.App", name: "org.extra.App", icon: "" },
    { id: "terminal", name: "Terminal", icon: "terminal" },
]);

console.log("PASS immutable notification application override settings rules");
