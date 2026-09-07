#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(
    path.join(root, "Titonium/Core/Runtime/PreferencesValidator.js"), "utf8");
const legacyCatalogContext = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root, 'Titonium/Services/Appearance/LegacyThemeCatalog.js'), 'utf8').replace(/^\.pragma.*$/mg, ''), legacyCatalogContext);
const catalogContext = vm.createContext({LegacyThemeCatalog:legacyCatalogContext});
vm.runInContext(fs.readFileSync(path.join(root, 'Titonium/Services/Appearance/ThemeCatalog.js'), 'utf8').replace(/^\.(pragma|import).*$/mg, ''), catalogContext);
const appearanceContext = vm.createContext({ThemeCatalog:catalogContext});
vm.runInContext(fs.readFileSync(path.join(root, 'Titonium/Services/Appearance/AppearanceRules.js'), 'utf8').replace(/^\.(pragma|import).*$/mg, ''), appearanceContext);
const context = vm.createContext({AppearanceRules:appearanceContext});
vm.runInContext(source.replace(/^\.(pragma|import).*$/mg, ""), context);
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
assert.equal(projectedDefaults.$schema, "titonium.settings/v8");
assert.equal(projectedDefaults.schemaVersion, 8);
assert.equal(projectedDefaults.locale, "vi");
assert.equal(projectedDefaults.appearance.mode, "dark");
assert.equal(projectedDefaults.appearance.themeId, "modern-flat");
assert.equal(projectedDefaults.modules.bar.workspaceCount, 5);
assert.equal(projectedDefaults.modules.bar.autoHide, false);
assert.equal(projectedDefaults.modules.bar.mascotEnabled, true);
assert.equal(projectedDefaults.modules.bar.height, 44);
assert.equal(projectedDefaults.modules.bar.mascot, "pig");
const compactPreferences = plain(context.project({ ...current, modules: { ...current.modules,
    bar: { height: 64, mascot: "pig-lavender" } } }, defaults, null));
assert.equal(compactPreferences.modules.bar.height, 64);
assert.equal(compactPreferences.modules.bar.mascot, "pig-lavender");
const dogPreferences = plain(context.project({ ...current, modules: { ...current.modules,
    bar: { mascot: "dog" } } }, defaults, null));
assert.equal(dogPreferences.modules.bar.mascot, "dog", "Dog selection survives preference projection");
const invalidCompactPreferences = plain(context.project({ ...current, modules: { ...current.modules,
    bar: { height: 900, mascot: "../../custom.qml" } } }, defaults, null));
assert.equal(invalidCompactPreferences.modules.bar.height, 64);
assert.equal(invalidCompactPreferences.modules.bar.mascot, "pig");
assert.equal(projectedDefaults.modules.bar.style, "connected");
assert.equal(projectedDefaults.modules.dock.visibilityMode, "auto-hide");
assert.deepEqual(projectedDefaults.modules.dock.pinnedIds, []);
assert.equal(projectedDefaults.modules.notifications.toastsEnabled, true);
assert.equal(projectedDefaults.modules.notifications.toastDuration, 5000);
assert.equal(projectedDefaults.modules.notifications.policyMode, "automatic");
assert.equal(projectedDefaults.modules.notifications.allowCriticalOnIsland, true);
assert.equal(projectedDefaults.modules.notifications.keepCriticalUnread, true);
assert.deepEqual(projectedDefaults.modules.notifications.applicationOverrides, {});

const migrated = plain(context.project(legacy, defaults, legacyDock));
assert.equal(migrated.$schema, "titonium.settings/v8");
assert.equal(migrated.schemaVersion, 8);
assert.equal(migrated.locale, "en");
assert.equal(migrated.appearance.mode, "light");
assert.equal(migrated.accessibility.reducedMotion, true);
assert.deepEqual(migrated.applications.hiddenIds, ["hidden.desktop"]);
assert.equal(migrated.modules.spotlight.pageTransition, "fade");
assert.equal(migrated.modules.spotlight.transitionDuration, 480);
assert.equal(migrated.modules.clock.use24Hour, false);
assert.equal(migrated.modules.audio.allowAmplification, true);
assert.equal(migrated.modules.bar.workspaceCount, 5);
assert.equal(migrated.modules.bar.mascotEnabled, true);
assert.equal(migrated.modules.dock.visibilityMode, "reserve-space");
assert.deepEqual(migrated.modules.dock.pinnedIds,
    ["firefox.desktop", "org.kde.dolphin.desktop"]);

const currentProjection = plain(context.project(current, defaults, legacyDock));
assert.equal(currentProjection.modules.bar.workspaceCount, 8);
assert.equal(currentProjection.modules.bar.autoHide, true);
assert.equal(currentProjection.modules.bar.mascotEnabled, true);
assert.equal(currentProjection.modules.dock.visibilityMode, "always-visible");
assert.deepEqual(currentProjection.modules.dock.pinnedIds,
    ["org.mozilla.firefox.desktop"]);
assert.equal(currentProjection.modules.notifications.toastsEnabled, false);
assert.equal(currentProjection.modules.notifications.toastDuration, 9000);
assert.equal(currentProjection.modules.notifications.policyMode, "automatic");
assert.equal(currentProjection.modules.notifications.allowCriticalOnIsland, true);
assert.equal(currentProjection.modules.notifications.keepCriticalUnread, true);
assert.deepEqual(currentProjection.modules.notifications.applicationOverrides, {});

const emptyCurrentDock = plain(context.project({
    schemaVersion: 7,
    modules: { dock: {} },
}, defaults, legacyDock));
assert.equal(emptyCurrentDock.modules.dock.visibilityMode, "auto-hide",
    "a present v7 Dock subtree wins over legacy visibility");
assert.deepEqual(emptyCurrentDock.modules.dock.pinnedIds, [],
    "a present v7 Dock subtree wins over legacy pins");

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
        notifications: {
            toastsEnabled: "yes",
            toastDuration: 1,
            policyMode: "unsafe",
            allowCriticalOnIsland: "yes",
            keepCriticalUnread: "yes",
            applicationOverrides: {
                " org.example.Mail ": "quiet",
                "org.example.Chat": "untrusted",
                "": "critical",
                7: "block",
            },
        },
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
assert.equal(invalid.modules.bar.mascotEnabled, true);
assert.equal(invalid.modules.dock.visibilityMode, "auto-hide");
assert.deepEqual(invalid.modules.dock.pinnedIds, ["A", "B"]);
assert.equal(invalid.modules.notifications.toastsEnabled, true);
assert.equal(invalid.modules.notifications.toastDuration, 2000);
assert.equal(invalid.modules.notifications.policyMode, "automatic");
assert.equal(invalid.modules.notifications.allowCriticalOnIsland, true);
assert.equal(invalid.modules.notifications.keepCriticalUnread, true);
assert.deepEqual(invalid.modules.notifications.applicationOverrides, {
    "7": "block",
    "org.example.Mail": "quiet",
});

const customNotifications = plain(context.project({
    modules: { notifications: {
        policyMode: "custom",
        allowCriticalOnIsland: false,
        keepCriticalUnread: false,
        applicationOverrides: {
            "org.example.Mail": "follow",
            "org.example.Chat": "quiet",
            "org.example.Calendar": "normal",
            "org.example.Build": "critical",
            "org.example.Spam": "block",
        },
    } },
}, defaults, null));
assert.equal(customNotifications.modules.notifications.policyMode, "custom");
assert.equal(customNotifications.modules.notifications.allowCriticalOnIsland, false);
assert.equal(customNotifications.modules.notifications.keepCriticalUnread, false);
assert.deepEqual(customNotifications.modules.notifications.applicationOverrides, {
    "org.example.Mail": "follow",
    "org.example.Chat": "quiet",
    "org.example.Calendar": "normal",
    "org.example.Build": "critical",
    "org.example.Spam": "block",
});

assert.equal(context.project({ modules: { bar: { style: "classic" } } }, defaults, null)
    .modules.bar.style, "classic");
assert.equal(context.project({ modules: { bar: { style: "detached-ish" } } }, defaults, null)
    .modules.bar.style, "connected");
assert.equal(context.project({ modules: { bar: { style: 12 } } }, defaults, null)
    .modules.bar.style, "connected");

// Dock theme overrides survive projection; legacy and invalid values follow Topbar.
for (const style of ["follow-topbar", "connected", "classic"]) {
    const projected = context.project({ schemaVersion: 7, modules: { dock: { style } } }, defaults, null);
    assert.equal(projected.modules.dock.style, style);
}
for (const style of [undefined, null, 12, "glass"]) {
    const projected = context.project({ schemaVersion: 7, modules: { dock: { style } } }, defaults, null);
    assert.equal(projected.modules.dock.style, "follow-topbar");
}
const dockPreview = context.setPath(migrated, "modules.dock.style", "classic");
assert.equal(context.project(dockPreview, defaults, null).modules.dock.style, "classic");
assert.equal(migrated.modules.dock.style, "follow-topbar", "preview preserves committed theme");

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

console.log("PASS settings v8 projection, migration and path fixtures (43)");

for (const version of [7,8]) {
 const projected = context.project({schemaVersion:version, appearance:{mode:'system',themeId:'glass'},modules:{dock:{visibilityMode:'hidden',pinnedIds:['keep.desktop'],style:'classic'}}},defaults,legacyDock);
 assert.equal(projected.appearance.mode,'system');
 assert.equal(projected.appearance.themeId,'glass');
 assert.equal(projected.modules.dock.visibilityMode,'hidden');
 assert.equal(projected.modules.dock.style,'classic');
 assert.deepEqual(plain(projected.modules.dock.pinnedIds),['keep.desktop']);
}
assert.equal(currentProjection.appearance.themeId,'neutral');
assert.equal(migrated.appearance.themeId,'neutral');

const v8 = fixture('settings-v8-runtime.json');
assert.deepEqual(plain(context.project(v8,defaults,legacyDock)),v8);
console.log('PASS v8 appearance round trip and v7/v8 Dock precedence');
