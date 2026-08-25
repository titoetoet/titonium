.pragma library

const nodeTypes = ["widget", "group", "panel", "tabs", "spacer"];
const backends = ["solid", "qml", "native"];

function validateSettings(data) {
    const errors = [];
    if (!data || typeof data !== "object") return ["settings must be an object"];
    if (data.schemaVersion !== 2) errors.push("unsupported settings schemaVersion");
    if (data.locale !== "vi" && data.locale !== "en") errors.push("locale must be vi or en");
    if (!data.appearance || typeof data.appearance !== "object" || Array.isArray(data.appearance)) {
        errors.push("appearance is required");
    } else {
        if (!data.appearance.themeId) errors.push("appearance.themeId is required");
        if (data.appearance.mode !== "dark" && data.appearance.mode !== "light") errors.push("appearance.mode is invalid");
        if (data.appearance.density !== "compact" && data.appearance.density !== "comfortable")
            errors.push("appearance.density is invalid");
        if (!data.appearance.overrides || typeof data.appearance.overrides !== "object" || Array.isArray(data.appearance.overrides))
            errors.push("appearance.overrides must be an object");
    }
    if (!data.accessibility || typeof data.accessibility.reducedMotion !== "boolean")
        errors.push("accessibility.reducedMotion is required");
    if (!data.modules || typeof data.modules !== "object" || Array.isArray(data.modules))
        errors.push("modules must be an object");
    return errors;
}

function validateNode(node, path, seen, errors) {
    if (!node || typeof node !== "object") {
        errors.push(path + " must be an object");
        return;
    }
    if (typeof node.id !== "string" || node.id.length === 0) {
        errors.push(path + ".id is required");
    } else if (seen[node.id]) {
        errors.push("duplicate node id: " + node.id);
    } else {
        seen[node.id] = true;
    }
    if (nodeTypes.indexOf(node.type) < 0) {
        errors.push(path + ".type is invalid");
        return;
    }
    if (node.type === "widget" && (typeof node.widgetType !== "string" || node.widgetType.length === 0))
        errors.push(path + ".widgetType is required");
    if (node.type === "group") {
        if (!Array.isArray(node.children)) errors.push(path + ".children must be an array");
        else node.children.forEach((child, index) => validateNode(child, path + ".children[" + index + "]", seen, errors));
    }
    if (node.type === "panel") {
        if (!node.child) errors.push(path + ".child is required");
        else validateNode(node.child, path + ".child", seen, errors);
    }
    if (node.type === "tabs") {
        if (!Array.isArray(node.pages) || node.pages.length === 0) {
            errors.push(path + ".pages must be a non-empty array");
        } else {
            node.pages.forEach((page, index) => {
                if (!page || !page.child) errors.push(path + ".pages[" + index + "].child is required");
                else validateNode(page.child, path + ".pages[" + index + "].child", seen, errors);
            });
        }
    }
}

function validateLayout(data) {
    const errors = [];
    const seen = {};
    if (!data || typeof data !== "object") return ["layout must be an object"];
    if (data.schemaVersion !== 1) errors.push("unsupported layout schemaVersion");
    const menubar = data.menubar;
    if (!menubar || typeof menubar !== "object") return errors.concat(["menubar is required"]);
    if (!Number.isInteger(menubar.height) || menubar.height < 28 || menubar.height > 72)
        errors.push("menubar.height must be an integer from 28 to 72");
    if (!menubar.screens || !menubar.screens.default)
        return errors.concat(["menubar.screens.default is required"]);
    Object.keys(menubar.screens).forEach(screenName => {
        const screen = menubar.screens[screenName];
        const slots = screen && screen.slots;
        if (!slots || typeof slots !== "object") {
            errors.push("screen " + screenName + " requires slots");
            return;
        }
        ["start", "center", "end"].forEach(slotName => {
            if (slots[slotName] === undefined) return;
            if (!Array.isArray(slots[slotName])) {
                errors.push("screen " + screenName + " slot " + slotName + " must be an array");
                return;
            }
            slots[slotName].forEach((node, index) => validateNode(node, screenName + "." + slotName + "[" + index + "]", seen, errors));
        });
    });
    return errors;
}

function validateTheme(data) {
    const errors = [];
    if (!data || typeof data !== "object") return ["theme must be an object"];
    if (data.schemaVersion !== 2) errors.push("unsupported theme schemaVersion");
    if (!data.id) errors.push("theme.id is required");
    if (!data.version) errors.push("theme.version is required");
    if (!data.nameKey) errors.push("theme.nameKey is required");
    if (typeof data.immutable !== "boolean") errors.push("theme.immutable is required");
    if (!data.modes || !data.modes.dark || !data.modes.light) errors.push("theme dark/light modes are required");
    ["typography", "metrics", "motion", "material"].forEach(key => {
        if (!data[key] || typeof data[key] !== "object") errors.push("theme." + key + " is required");
    });
    if (data.material && backends.indexOf(data.material.defaultBackend) < 0)
        errors.push("theme.material.defaultBackend is invalid");
    if (data.material && (!Array.isArray(data.material.allowedBackends) || data.material.allowedBackends.length === 0))
        errors.push("theme.material.allowedBackends is required");
    if (data.material && typeof data.material.compositorIntegration !== "boolean")
        errors.push("theme.material.compositorIntegration is required");
    return errors;
}

function validateThemeCatalog(data) {
    const errors = [];
    if (!data || typeof data !== "object") return ["theme catalog must be an object"];
    if (data.schemaVersion !== 1) errors.push("unsupported theme catalog schemaVersion");
    if (!data.defaultThemeId) errors.push("theme catalog defaultThemeId is required");
    if (!Array.isArray(data.themes) || data.themes.length === 0) {
        errors.push("theme catalog themes are required");
        return errors;
    }
    const seen = {};
    data.themes.forEach((entry, index) => {
        if (!entry || !entry.id || !entry.file) errors.push("theme catalog entry " + index + " is invalid");
        else if (entry.file.indexOf("/") >= 0 || entry.file.indexOf("..") >= 0 || !entry.file.endsWith(".json"))
            errors.push("theme catalog entry " + entry.id + " has an invalid file name");
        else if (seen[entry.id]) errors.push("duplicate theme catalog id: " + entry.id);
        else seen[entry.id] = true;
    });
    if (!seen[data.defaultThemeId]) errors.push("theme catalog default is not registered");
    return errors;
}
