#!/usr/bin/env node

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const projectRoot = path.resolve(__dirname, "..");
const migrationsPath = path.join(projectRoot, "Titonium/Foundation/ConfigMigrations.js");
const migrationsSource = fs.readFileSync(migrationsPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const context = vm.createContext({});
vm.runInContext(migrationsSource, context, { filename: migrationsPath });
const validatorPath = path.join(projectRoot, "Titonium/Foundation/ConfigValidator.js");
const validatorSource = fs.readFileSync(validatorPath, "utf8").replace(/^\.pragma library\s*\n/, "");
const validatorContext = vm.createContext({});
vm.runInContext(validatorSource, validatorContext, { filename: validatorPath });

const shippedSettings = JSON.parse(fs.readFileSync(
    path.join(projectRoot, "config/defaults/settings.json"), "utf8"));
assert.deepEqual(
    JSON.parse(JSON.stringify(validatorContext.validateSettings(shippedSettings))),
    [],
    "runtime validator must accept shipped settings v5",
);
for (const [label, hiddenIds, expected] of [
    ["duplicate", ["a.desktop", "a.desktop"], "applications.hiddenIds must contain unique IDs"],
    ["empty", [""], "applications.hiddenIds entries must be non-empty strings"],
    ["non-string", [3], "applications.hiddenIds entries must be non-empty strings"],
]) {
    const derivative = JSON.parse(JSON.stringify(shippedSettings));
    derivative.applications.hiddenIds = hiddenIds;
    assert.deepEqual(
        JSON.parse(JSON.stringify(validatorContext.validateSettings(derivative))),
        [expected],
        `runtime validator must reject ${label} hidden IDs independently`,
    );
}

const moduleValues = [
    { label: "missing", include: false, value: undefined },
    { label: "null", include: true, value: null },
    { label: "array", include: true, value: [] },
];

for (const schemaVersion of [1, 2, 3, 4, 5]) {
    for (const moduleCase of moduleValues) {
        const source = { schemaVersion };
        if (moduleCase.include)
            source.modules = moduleCase.value;

        let migrated;
        assert.doesNotThrow(
            () => { migrated = context.migrateSettings(source); },
            `v${schemaVersion} settings with ${moduleCase.label} modules must not throw`,
        );
        assert.notStrictEqual(migrated, source, "migration must return a clone");

        if (schemaVersion < 5) {
            assert.equal(migrated.schemaVersion, 5, `v${schemaVersion} settings must reach v5`);
            assert.deepEqual(
                JSON.parse(JSON.stringify(migrated.applications)),
                { hiddenIds: [] },
                "migrated global application visibility defaults must be present",
            );
        }
        if (schemaVersion < 4) {
            assert.equal(Array.isArray(migrated.modules), false, "migrated modules must be an object");
            assert.equal(typeof migrated.modules, "object", "migrated modules must be an object");
            assert.deepEqual(
                JSON.parse(JSON.stringify(migrated.modules.spotlight)),
                { pageTransition: "slide-fade", transitionDuration: 220 },
                "migrated Spotlight defaults must be present",
            );
        } else if (schemaVersion === 5) {
            assert.equal(migrated.schemaVersion, 5, "v5 settings must remain v5");
            assert.equal("modules" in migrated, moduleCase.include, "v5 modules must remain unchanged");
            if (moduleCase.include)
                assert.equal(Array.isArray(migrated.modules), Array.isArray(moduleCase.value), "v5 modules must remain unchanged");
        }
    }
}

console.log("PASS ConfigMigrations normalizes malformed legacy modules");
