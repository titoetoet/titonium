#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Bar", "islands",
    "CenterPresentationRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing CenterPresentationRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

assert.equal(rules.leadingIcon({
    source: "clipboard",
    icon: "content_copy",
    title: "Đã sao chép · hello",
}, { icon: "work" }), "content_copy");
assert.equal(rules.leadingIcon({
    source: "notification",
    icon: "notifications",
    title: "Bạn có một notification",
}, null), "notifications");
assert.equal(rules.leadingIcon(null, { icon: "work" }), "work");
assert.equal(rules.leadingIcon(null, null), "center_focus_strong");
assert.equal(rules.leadingIcon(null, null, [
    { id: "notification", icon: "mark_email_unread" },
    { id: "media", icon: "music_note" },
]), "center_focus_strong");
assert.equal(rules.leadingIcon({ icon: "   " }, null), "center_focus_strong");
console.log("PASS each Center presentation owns exactly one matching icon");
