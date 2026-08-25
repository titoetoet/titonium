.pragma library

const nodeTypes = ["widget", "group", "panel", "tabs", "spacer"];
const backends = ["auto", "native", "qml", "solid"];

function validateSettings(data) {
    const errors = [];
    if (!data || typeof data !== "object") return ["settings must be an object"];
    if (data.schemaVersion !== 1) errors.push("unsupported settings schemaVersion");
    if (data.locale !== "vi" && data.locale !== "en") errors.push("locale must be vi or en");
    if (!data.theme || typeof data.theme !== "object") {
        errors.push("theme is required");
    } else {
        if (!data.theme.id) errors.push("theme.id is required");
        if (data.theme.mode !== "dark" && data.theme.mode !== "light") errors.push("theme.mode is invalid");
        if (backends.indexOf(data.theme.materialBackend) < 0) errors.push("theme.materialBackend is invalid");
    }
    if (!data.accessibility || typeof data.accessibility.reducedMotion !== "boolean")
        errors.push("accessibility.reducedMotion is required");
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
    if (data.schemaVersion !== 1) errors.push("unsupported theme schemaVersion");
    if (!data.id) errors.push("theme.id is required");
    if (!data.modes || !data.modes.dark || !data.modes.light) errors.push("theme dark/light modes are required");
    ["typography", "metrics", "motion", "materials"].forEach(key => {
        if (!data[key] || typeof data[key] !== "object") errors.push("theme." + key + " is required");
    });
    return errors;
}
