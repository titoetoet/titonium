#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Bar", "islands", "ActiveWindowRules.js");
const pillPath = path.join(root, "Titonium", "Bar", "islands", "ActiveWindowPill.qml");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Bar/islands/ActiveWindowRules.js");
    process.exit(1);
}
if (!fs.existsSync(pillPath)) {
    console.error("FAIL missing Titonium/Bar/islands/ActiveWindowPill.qml");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

assert.equal(rules.label("Codex", "Reviewing changes"), "Codex · Reviewing changes");
assert.equal(rules.label("Firefox", "Firefox"), "Firefox");
assert.equal(rules.label("", ""), "Titonium");
assert.equal(rules.label("Kitty", "   "), "Kitty");
assert.equal(rules.label("", "  Syncing  "), "Titonium · Syncing");
console.log("PASS StartIsland app-context label normalization fixtures");

assert.equal(typeof rules.presentation, "function",
    "StartIsland rules must project separate app and context fields");
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "Telegram", "3 unread messages", "Telegram system title", true))),
    { appName: "Telegram", title: "Telegram system title", hasContext: true });
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "Firefox", "", "MDN — Firefox", false))),
    { appName: "Firefox", title: "MDN — Firefox", hasContext: true });
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "", "", "", false))),
    { appName: "Titonium", title: "", hasContext: false });
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "ChatGPT", "", "Private system title", true))),
    { appName: "ChatGPT", title: "Private system title", hasContext: true },
    "a menu-bearing app still presents its compositor window title");
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "Antigravity IDE", "", "titonium - Antigravity IDE - BluetoothDeviceRow.qml", false))),
    { appName: "Antigravity IDE", title: "titonium - BluetoothDeviceRow.qml", hasContext: true },
    "middle app name segment in IDE titles must be stripped for a clean pill");
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "Antigravity", "", "Mijia Evaporative Fan Res...", true))),
    { appName: "Antigravity", title: "Mijia Evaporative Fan Res...", hasContext: true },
    "a tray app without menu context must fall back to its window title");
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "Antigravity", "1 agent running", "Mijia Evaporative Fan Res...", true))),
    { appName: "Antigravity", title: "Mijia Evaporative Fan Res...", hasContext: true },
    "window title must take precedence over menu task context");
assert.deepEqual(JSON.parse(JSON.stringify(rules.presentation(
    "ChatGPT", "Cân giữa menu và resize pill", "", true))),
    { appName: "ChatGPT", title: "Cân giữa menu và resize pill", hasContext: true },
    "the first menu task becomes Window Title fallback when compositor title is empty");
console.log("PASS StartIsland title-first and first-task fallback fixtures");

const pill = fs.readFileSync(pillPath, "utf8");
for (const fragment of [
    "HyprlandService.activeWindow",
    "ApplicationService.nameForAppId",
    "SystemTrayService.menuContextForApp",
    "ActiveWindowRules.label",
    "implicitWidth: Math.min(520",
    "activityRow.implicitWidth",
    "readonly property var presentation:",
    "id: appNameLabel",
    "Layout.maximumWidth: 120",
    "id: activityDot",
    "text: \"·\"",
    "visible: root.presentation.hasContext",
    "id: titleLabel",
    "Text.ElideRight",
    "maximumLineCount: 1",
]) {
    assert.equal(pill.includes(fragment), true, `ActiveWindowPill missing ${fragment}`);
}
assert.equal(pill.includes("activeWindow?.title"), true,
    "StartIsland must retain compositor-title fallback for apps without a tray menu");
assert.equal(pill.includes("implicitWidth: 420"), false,
    "Active Window must not retain the old fixed width");
assert.equal(pill.includes("id: activitySeparator"), false,
    "Center content must not use a vertical divider");
assert.equal(pill.includes("Layout.preferredWidth: 120"), false,
    "short app names must not leave a fixed-width gap before the title");
assert.equal(pill.includes("strong: root.notchOpen"), false,
    "opening Center must not change title font metrics or resize the left pill");
assert.match(pill, /id:\s*titleLabel[\s\S]*?strong:\s*false/,
    "window title must keep stable regular-weight metrics");
console.log("PASS bounded natural-width active-window presentation contract");
