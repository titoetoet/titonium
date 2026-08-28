#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const catalogPath = path.join(__dirname, "..", "Titonium", "Settings", "SettingsCatalog.js");
if (!fs.existsSync(catalogPath)) {
    console.error("FAIL Settings catalog is missing");
    process.exit(1);
}

const source = fs.readFileSync(catalogPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: catalogPath });
const plain = value => JSON.parse(JSON.stringify(value));

assert.deepEqual(plain(context.pageIds()), ["general", "appearance", "spotlight", "bar", "dock",
    "notifications", "audio", "about"]);
assert.equal(context.normalizePage("general"), "general");
assert.equal(context.normalizePage(" GENERAL "), "general");
assert.equal(context.normalizePage(""), "general");
assert.equal(context.normalizePage("missing"), "general");
assert.equal(context.normalizePage(null), "general");

const entries = plain(context.navigationEntries());
assert.deepEqual(entries, [
    { id: "general", icon: "tune", labelKey: "settings.nav.general" },
    { id: "appearance", icon: "palette", labelKey: "settings.nav.appearance" },
    { id: "spotlight", icon: "rocket_launch", labelKey: "settings.nav.spotlight" },
    { id: "bar", icon: "toolbar", labelKey: "settings.nav.bar" },
    { id: "dock", icon: "dock_to_bottom", labelKey: "settings.nav.dock" },
    { id: "notifications", icon: "notifications", labelKey: "settings.nav.notifications" },
    { id: "audio", icon: "volume_up", labelKey: "settings.nav.audio" },
    { id: "about", icon: "info", labelKey: "settings.nav.about" },
]);
assert.equal(Object.isFrozen(context.navigationEntries()), true);
assert.equal(Object.isFrozen(context.navigationEntries()[0]), true);

console.log("PASS Settings catalog normalization fixtures");
