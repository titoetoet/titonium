.pragma library

function clone(value) {
    return value === undefined || value === null ? value : JSON.parse(JSON.stringify(value));
}

function migrateSettings(data) {
    if (!data || typeof data !== "object")
        return data;
    if (data.schemaVersion === 2)
        return clone(data);
    if (data.schemaVersion !== 1)
        return clone(data);

    const legacyTheme = data.theme && typeof data.theme === "object" ? data.theme : {};
    const legacyAccessibility = data.accessibility && typeof data.accessibility === "object"
        ? data.accessibility
        : {};
    const legacyModules = data.modules && typeof data.modules === "object" && !Array.isArray(data.modules)
        ? data.modules
        : {};

    return {
        "$schema": "titonium.settings/v2",
        "schemaVersion": 2,
        "locale": data.locale === "en" ? "en" : "vi",
        "appearance": {
            "themeId": "titonium-neutral",
            "mode": legacyTheme.mode === "light" ? "light" : "dark",
            "density": "comfortable",
            "overrides": {}
        },
        "accessibility": {
            "reducedMotion": legacyAccessibility.reducedMotion === true
        },
        "modules": clone(legacyModules)
    };
}
