#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const projectRoot = path.resolve(__dirname, "..");
const helperPath = path.join(projectRoot, "Titonium/Services/Applications/Visibility.js");
const projectionPath = path.join(projectRoot, "Titonium/Services/Applications/ApplicationProjection.js");
if (!fs.existsSync(helperPath)) {
    console.error("FAIL application visibility helper is missing");
    process.exit(1);
}
const source = fs.readFileSync(helperPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(source, context, { filename: helperPath });
const plain = value => JSON.parse(JSON.stringify(value));

if (!fs.existsSync(projectionPath)) {
    console.error("FAIL application projection helper is missing");
    process.exit(1);
}
const projectionSource = fs.readFileSync(projectionPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const projection = vm.createContext({});
vm.runInContext(projectionSource, projection, { filename: projectionPath });

assert.deepEqual(
    plain(projection.categoryNames({ 0: "GNOME", 1: "Network", length: 2 })),
    ["GNOME", "Network"],
    "QStringList-like desktop categories remain available to the Spotlight catalog",
);
assert.deepEqual(
    plain(projection.categoryNames(["Development", "Utility", ""])),
    ["Development", "Utility"],
    "category projection removes empty values without changing order",
);

assert.deepEqual(
    plain(context.normalizeHidden(["b.desktop", "a.desktop", "b.desktop", "", 3, "__proto__"])),
    ["b.desktop", "a.desktop", "__proto__"],
    "hidden IDs normalize without losing first-seen order or special keys",
);
const apps = [
    { id: "a.desktop", name: "Alpha" },
    { id: "b.desktop", name: "Beta" },
    { id: "c.desktop", name: "Charlie" },
];
assert.deepEqual(
    plain(context.filterVisible(apps, ["b.desktop"])).map(app => app.id),
    ["a.desktop", "c.desktop"],
    "visible projection removes hidden installed records",
);
assert.equal(context.isVisible(["b.desktop"], "a.desktop"), true);
assert.equal(context.isVisible(["b.desktop"], "b.desktop"), false);
assert.deepEqual(
    plain(context.setVisible(["missing.desktop", "a.desktop"], "a.desktop", true)),
    ["missing.desktop"],
    "showing an app preserves missing hidden IDs",
);
assert.deepEqual(
    plain(context.setVisible(["missing.desktop"], "a.desktop", false)),
    ["missing.desktop", "a.desktop"],
    "hiding an app appends its ID deterministically",
);
assert.deepEqual(
    plain(context.setVisible(["a.desktop"], "a.desktop", false)),
    ["a.desktop"],
    "hiding an already hidden app is idempotent",
);
assert.deepEqual(plain(context.setVisible(["a.desktop"], "", false)), ["a.desktop"]);

console.log("PASS application visibility fixtures (9)");
