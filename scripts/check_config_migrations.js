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

const moduleValues = [
    { label: "missing", include: false, value: undefined },
    { label: "null", include: true, value: null },
    { label: "array", include: true, value: [] },
];

for (const schemaVersion of [1, 2, 3, 4]) {
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

        if (schemaVersion < 4) {
            assert.equal(migrated.schemaVersion, 4, `v${schemaVersion} settings must reach v4`);
            assert.equal(Array.isArray(migrated.modules), false, "migrated modules must be an object");
            assert.equal(typeof migrated.modules, "object", "migrated modules must be an object");
            assert.deepEqual(
                JSON.parse(JSON.stringify(migrated.modules.spotlight)),
                { pageTransition: "slide-fade", transitionDuration: 220 },
                "migrated Spotlight defaults must be present",
            );
        } else {
            assert.equal(migrated.schemaVersion, 4, "v4 settings must remain v4");
            assert.equal("modules" in migrated, moduleCase.include, "v4 modules must remain unchanged");
            if (moduleCase.include)
                assert.equal(Array.isArray(migrated.modules), Array.isArray(moduleCase.value), "v4 modules must remain unchanged");
        }
    }
}

console.log("PASS ConfigMigrations normalizes malformed legacy modules");
