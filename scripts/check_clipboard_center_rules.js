#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Clipboard",
    "ClipboardCenterRules.js");
if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing ClipboardCenterRules.js");
    process.exit(1);
}
const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext("String.prototype.trimEnd = undefined;", rules);
vm.runInContext(source, rules, { filename: rulesPath });
const plain = value => JSON.parse(JSON.stringify(value));

let emptyBaseline = rules.observe(
    rules.initialState(), "   ", "Đã sao chép", 500);
assert.equal(emptyBaseline.event, null);
assert.equal(emptyBaseline.next.initialized, true);
const firstRealCopy = rules.observe(
    emptyBaseline.next, "first real copy", "Đã sao chép", 750);
assert.equal(firstRealCopy.event.title, "Đã sao chép · first real copy");

let result = rules.observe(rules.initialState(), "existing clipboard", "Đã sao chép", 1000);
assert.equal(result.event, null);
assert.equal(result.next.initialized, true);

result = rules.observe(result.next, "existing clipboard", "Đã sao chép", 2000);
assert.equal(result.event, null);

result = rules.observe(result.next,
    "  A very   useful copied value that is deliberately longer than sixty four characters.  ",
    "Đã sao chép", 3000);
assert.deepEqual(plain(result.event), {
    id: "clipboard:current",
    deduplicationKey: "clipboard:current",
    source: "clipboard",
    kind: "copied",
    title: "Đã sao chép · A very useful copied value that is deliberately longer than six…",
    icon: "content_copy",
    createdAt: 3000,
});
assert.equal(rules.observe(result.next, "   ", "Đã sao chép", 4000).event, null);

assert.equal(rules.decodeWatchLine(JSON.stringify("Xin chào\nTitonium")),
    "Xin chào\nTitonium");
assert.equal(rules.decodeWatchLine(JSON.stringify("")), "");
assert.equal(rules.decodeWatchLine("{broken"), null);
assert.equal(rules.decodeWatchLine(JSON.stringify({ text: "wrong shape" })), null);
console.log("PASS Clipboard watcher decoding, baseline, deduplication and bounded Center preview");
