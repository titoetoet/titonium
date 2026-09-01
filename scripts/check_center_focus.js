#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const rulesPath = path.join(root, "Titonium", "Services", "Center",
    "CenterFocusRules.js");

if (!fs.existsSync(rulesPath)) {
    console.error("FAIL missing Titonium/Services/Center/CenterFocusRules.js");
    process.exit(1);
}

const source = fs.readFileSync(rulesPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const rules = vm.createContext({});
vm.runInContext(source, rules, { filename: rulesPath });

const morning = new Date(2026, 7, 28, 8, 0);
const noon = new Date(2026, 7, 28, 12, 0);
assert.equal(rules.dateKey(noon), "2026-08-28");
assert.deepEqual(Array.from(rules.lines(" A \r\n\r\n B\r\n")), ["A", "B"]);
assert.equal(rules.select({
    markdown: "Deep Work Mode\n\n- ship Center",
    modifiedAt: morning.getTime(),
    prompts: "Calm is fast\nProtect the goal",
}, noon), "Deep Work Mode");
assert.equal(rules.select({
    markdown: "  # Today  \r\n\r\n## Center\r\n  Ship the true center  ",
    modifiedAt: morning.getTime(),
    prompts: "Fallback",
}, noon), "Ship the true center");
console.log("PASS same-day explicit focus and Markdown normalization");

const previousDay = new Date(2026, 7, 27, 23, 59);
assert.equal(rules.explicitFocus("Yesterday's goal", previousDay.getTime(), noon), "");
assert.equal(rules.explicitFocus("Today's goal", morning.getTime(), noon), "Today's goal");
assert.equal(rules.explicitFocus("   \n # Heading only", morning.getTime(), noon), "");
console.log("PASS explicit focus is valid only for its local date");

const fallbackState = {
    markdown: "",
    modifiedAt: 0,
    prompts: " Calm is fast \r\n\r\n Protect the goal\r\nShip one thing",
};
const dayMorning = new Date(2026, 7, 29, 9, 0);
const dayEvening = new Date(2026, 7, 29, 21, 0);
const first = rules.select(fallbackState, dayMorning);
const second = rules.select(fallbackState, dayEvening);
assert.equal(first, second);
assert.equal(Array.from(rules.lines(fallbackState.prompts)).includes(first), true);
assert.equal(rules.deterministicFallback(fallbackState.prompts, dayMorning), first);
assert.equal(rules.select({ markdown: "", modifiedAt: 0, prompts: "" }, dayMorning), "");
console.log("PASS prompt fallback is deterministic for one local date");

assert.equal(rules.sanitizeInput("  Ship   the\nCenter  "), "Ship the Center");
assert.equal(rules.sanitizeInput("   \n  "), "");
console.log("PASS inline focus input normalizes to one compact line");

const observed = new Set();
for (let day = 1; day <= 31; day += 1)
    observed.add(rules.deterministicFallback("One\nTwo\nThree", new Date(2026, 7, day)));
assert.equal(observed.size > 1, true);
console.log("PASS stable date hashing distributes normalized prompts");

const centerIsland = fs.readFileSync(path.join(root, "Titonium", "Bar", "islands",
    "CenterIsland.qml"), "utf8");
const overview = fs.readFileSync(path.join(root, "Titonium", "Bar", "notch",
    "OverviewPage.qml"), "utf8");
const overviewFocus = fs.readFileSync(path.join(root, "Titonium", "Bar", "notch",
    "OverviewFocusCard.qml"), "utf8");
assert.equal(centerIsland.includes("CenterFocusStore.openScratchpad()"), false,
    "TopBar Center must open the Notch instead of Daily Focus directly");
assert.match(centerIsland, /signal notchRequested\(var screen\)/);
assert.equal((overviewFocus.match(/CenterFocusStore\.openScratchpad\(\)/g) || []).length, 1,
    "Overview owns one explicit Daily Focus action");
assert.match(overview, /OverviewFocusCard/);
assert.match(overviewFocus, /center_notch\.overview\.focus\.title/);
assert.match(overviewFocus, /center_notch\.overview\.daily_focus\.open/);
assert.match(overviewFocus, /QtControls\.TextField/);
assert.match(overviewFocus, /CenterFocusStore\.saveToday\(focusInput\.text\)/);
console.log("PASS Daily Focus moved behind explicit Center Overview action");
