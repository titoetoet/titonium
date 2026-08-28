#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(
    path.join(root, "Titonium/Core/Runtime/PreferencesValidator.js"), "utf8");
const context = vm.createContext({});
vm.runInContext(source.replace(/^\.pragma library\s*\n/, ""), context);
const plain = value => JSON.parse(JSON.stringify(value));
const fixture = name => JSON.parse(fs.readFileSync(
    path.join(root, "tests/fixtures", name), "utf8"));
const defaults = JSON.parse(fs.readFileSync(
    path.join(root, "config/defaults/settings.json"), "utf8"));
const legacy = fixture("settings-v6-runtime.json");
const current = fixture("settings-v7-runtime.json");
const legacyDock = fixture("dock-v1-runtime.json");

assert.equal(typeof context.project, "function", "project API exists");
assert.equal(typeof context.clone, "function", "clone API exists");
assert.equal(typeof context.setPath, "function", "setPath API exists");
assert.equal(typeof context.same, "function", "same API exists");
assert.equal(typeof context.normalizePinnedIds, "function", "Dock normalization API exists");
assert.equal(typeof context.dockModeFromLegacy, "function", "Dock migration API exists");

const projectedDefaults = plain(context.project(null, defaults, null));
assert.equal(projectedDefaults.$schema, "titonium.settings/v7");
assert.equal(projectedDefaults.schemaVersion, 7);
assert.equal(projectedDefaults.locale, "vi");
assert.equal(projectedDefaults.appearance.mode, "dark");
assert.equal(projectedDefaults.modules.bar.workspaceCount, 5);
assert.equal(projectedDefaults.modules.bar.autoHide, false);
assert.equal(projectedDefaults.modules.dock.visibilityMode, "auto-hide");
assert.deepEqual(projectedDefaults.modules.dock.pinnedIds, []);
assert.equal(projectedDefaults.modules.notifications.toastsEnabled, true);
assert.equal(projectedDefaults.modules.notifications.toastDuration, 5000);

const migrated = plain(context.project(legacy, defaults, legacyDock));
assert.equal(migrated.$schema, "titonium.settings/v7");
assert.equal(migrated.schemaVersion, 7);
assert.equal(migrated.locale, "en");
assert.equal(migrated.appearance.mode, "light");
assert.equal(migrated.accessibility.reducedMotion, true);
assert.deepEqual(migrated.applications.hiddenIds, ["hidden.desktop"]);
assert.equal(migrated.modules.spotlight.pageTransition, "fade");
assert.equal(migrated.modules.spotlight.transitionDuration, 480);
assert.equal(migrated.modules.clock.use24Hour, false);
assert.equal(migrated.modules.audio.allowAmplification, true);
assert.equal(migrated.modules.bar.workspaceCount, 5);
assert.equal(migrated.modules.dock.visibilityMode, "reserve-space");
assert.deepEqual(migrated.modules.dock.pinnedIds,
    ["firefox.desktop", "org.kde.dolphin.desktop"]);

const currentProjection = plain(context.project(current, defaults, legacyDock));
assert.equal(currentProjection.modules.bar.workspaceCount, 8);
assert.equal(currentProjection.modules.bar.autoHide, true);
assert.equal(currentProjection.modules.dock.visibilityMode, "always-visible");
assert.deepEqual(currentProjection.modules.dock.pinnedIds,
    ["org.mozilla.firefox.desktop"]);
assert.equal(currentProjection.modules.notifications.toastsEnabled, false);
assert.equal(currentProjection.modules.notifications.toastDuration, 9000);

const invalid = plain(context.project({
    schemaVersion: 7,
    locale: "invalid",
    appearance: { mode: "sepia" },
    accessibility: { reducedMotion: "yes" },
    applications: { hiddenIds: ["a.desktop", "a.desktop", 3] },
    modules: {
        spotlight: { pageTransition: "spin", transitionDuration: 999 },
        bar: { workspaceCount: 99, autoHide: "yes" },
        dock: { visibilityMode: "glass", pinnedIds: ["A", "a", "B"] },
        notifications: { toastsEnabled: "yes", toastDuration: 1 },
        clock: { use24Hour: "yes" },
        audio: { allowAmplification: "yes" },
    },
}, defaults, null));
assert.equal(invalid.locale, "vi");
assert.equal(invalid.appearance.mode, "dark");
assert.equal(invalid.accessibility.reducedMotion, false);
assert.deepEqual(invalid.applications.hiddenIds, ["a.desktop"]);
assert.equal(invalid.modules.spotlight.pageTransition, "slide-fade");
assert.equal(invalid.modules.spotlight.transitionDuration, 500);
assert.equal(invalid.modules.bar.workspaceCount, 8);
assert.equal(invalid.modules.bar.autoHide, false);
assert.equal(invalid.modules.dock.visibilityMode, "auto-hide");
assert.deepEqual(invalid.modules.dock.pinnedIds, ["A", "B"]);
assert.equal(invalid.modules.notifications.toastsEnabled, true);
assert.equal(invalid.modules.notifications.toastDuration, 2000);

assert.deepEqual(plain(context.normalizePinnedIds(
    [" b.desktop ", "B.DESKTOP", "a.desktop", "", 2])),
    ["b.desktop", "a.desktop"]);
assert.equal(context.dockModeFromLegacy({ pinnedOpen: true, autoHide: false }),
    "reserve-space");
assert.equal(context.dockModeFromLegacy({ pinnedOpen: false, autoHide: false }),
    "always-visible");
assert.equal(context.dockModeFromLegacy({ pinnedOpen: false, autoHide: true }),
    "auto-hide");

const candidate = plain(context.setPath(migrated,
    "modules.bar.workspaceCount", 7));
assert.equal(candidate.modules.bar.workspaceCount, 7);
assert.equal(migrated.modules.bar.workspaceCount, 5,
    "setPath does not mutate its input");
assert.equal(context.same(candidate, migrated), false);
assert.equal(context.same(context.clone(migrated), migrated), true);
assert.throws(() => context.setPath(migrated, "modules..bar", 4));
assert.throws(() => context.setPath(migrated, "__proto__.polluted", true));
assert.throws(() => context.setPath(migrated, "modules.constructor.value", true));

console.log("PASS settings v7 projection, migration and path fixtures (37)");
