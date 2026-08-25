#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const projectRoot = path.resolve(__dirname, "..");
const sourcePath = path.join(
    projectRoot,
    "Titonium/Modules/MenuBar/ArchMenu/ArchMenuModel.js"
);

if (!fs.existsSync(sourcePath)) {
    console.error("FAIL Arch Menu model is missing");
    process.exit(1);
}

const context = {};
vm.createContext(context);
const source = fs.readFileSync(sourcePath, "utf8").replace(/^\.pragma library\s*/, "");
vm.runInContext(source, context, { filename: sourcePath });

function fail(message) {
    console.error(`FAIL ${message}`);
    process.exit(1);
}

function deepPlain(value) {
    return JSON.parse(JSON.stringify(value));
}

const groups = deepPlain(context.groups);
if (!Array.isArray(groups))
    fail("Arch Menu model must export groups");

if (typeof context.routeFor !== "function")
    fail("Arch Menu model must export routeFor");
if (context.routeFor({ id: "future-tool", requiresConfirmation: false }) !== "unknown")
    fail("unknown non-confirming Arch Menu IDs must route to the warning path");
if (context.routeFor({ id: "settings", requiresConfirmation: false }) !== "settings")
    fail("Settings must retain its standalone route");
if (context.routeFor({ id: "lock", requiresConfirmation: true }) !== "confirm")
    fail("confirming session IDs must retain the confirmation route");

const expectedIds = [
    ["about"],
    ["settings"],
    ["lock", "sleep", "hibernate"],
    ["restart", "shutdown"],
    ["logout"]
];
const actualIds = groups.map(group => group.map(item => item.id));
if (JSON.stringify(actualIds) !== JSON.stringify(expectedIds)) {
    fail(`Arch Menu groups: expected ${JSON.stringify(expectedIds)}, received ${JSON.stringify(actualIds)}`);
}

const sessionIds = new Set(["lock", "sleep", "hibernate", "restart", "shutdown", "logout"]);
for (const group of groups) {
    for (const item of group) {
        if (typeof item.labelKey !== "string" || item.labelKey.length === 0)
            fail(`${item.id} must provide a label key`);
        if (typeof item.icon !== "string" || item.icon.length === 0)
            fail(`${item.id} must provide an icon`);
        if (sessionIds.has(item.id) && item.requiresConfirmation !== true)
            fail(`${item.id} must require confirmation`);
    }
}

const viStrings = JSON.parse(fs.readFileSync(
    path.join(projectRoot, "config/i18n/vi.json"),
    "utf8",
)).strings;
if (!/^Giao diện\s*·\s*\{theme\}$/.test(viStrings["arch_menu.about.theme"] || ""))
    fail("Vietnamese About theme prefix must be localized");

console.log("PASS Arch Menu model contract (8 items, 5 groups)");
