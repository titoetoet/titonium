#!/usr/bin/env node

const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(
    path.join(root, "Titonium/Core/Runtime/PreferencesValidator.js"),
    "utf8"
);
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

const defaults = JSON.parse(fs.readFileSync(
    path.join(root, "config/defaults/settings.json"),
    "utf8"
));

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

const projectedDefaults = context.project(defaults, defaults);
assert(defaults.$schema === "titonium.settings/v6" && defaults.schemaVersion === 6,
    "defaults use the v6 settings schema");
assert(projectedDefaults.locale === "vi", "defaults keep the Vietnamese locale");
assert(projectedDefaults.appearance.mode === "dark", "defaults keep dark mode");
assert(projectedDefaults.modules.clock.use24Hour === true, "defaults keep 24-hour clock");
assert(projectedDefaults.modules.audio.allowAmplification === false,
    "defaults disable audio amplification");

const legacyRuntime = {
    schemaVersion: 5,
    locale: "en",
    appearance: {
        themeId: "retired-theme",
        mode: "light",
        density: "compact",
        overrides: { unused: true }
    },
    accessibility: { reducedMotion: true },
    applications: { hiddenIds: ["one.desktop", 7, "two.desktop"] },
    modules: {
        frame: { enabled: true },
        audio: { maxVolume: 150 },
        spotlight: { pageTransition: "fade", transitionDuration: 700 },
        clock: { use24Hour: false }
    }
};
const projectedLegacy = context.project(legacyRuntime, defaults);
assert(projectedLegacy.locale === "en", "legacy runtime locale is preserved");
assert(projectedLegacy.appearance.mode === "light", "legacy runtime mode is preserved");
assert(projectedLegacy.accessibility.reducedMotion === true, "reduced motion is preserved");
assert(projectedLegacy.applications.hiddenIds.join(",") === "one.desktop,two.desktop",
    "only valid hidden application IDs are projected");
assert(projectedLegacy.modules.spotlight.pageTransition === "fade",
    "supported Spotlight transition is preserved");
assert(projectedLegacy.modules.spotlight.transitionDuration === 500,
    "Spotlight transition duration is clamped");
assert(projectedLegacy.modules.clock.use24Hour === false, "clock preference is preserved");
assert(projectedLegacy.modules.frame === undefined, "retired module settings do not enter the protected runtime state");
assert(projectedLegacy.modules.audio.allowAmplification === false,
    "legacy maxVolume does not enable amplification");

const currentRuntime = {
    schemaVersion: 6,
    locale: "vi",
    appearance: { mode: "dark" },
    accessibility: { reducedMotion: false },
    applications: { hiddenIds: [] },
    modules: {
        spotlight: { pageTransition: "slide-fade", transitionDuration: 220 },
        clock: { use24Hour: true },
        audio: { allowAmplification: true }
    }
};
assert(context.project(currentRuntime, defaults).modules.audio.allowAmplification === true,
    "v6 amplification preference is preserved");

console.log("PASS protected preference projection and legacy runtime tolerance");
