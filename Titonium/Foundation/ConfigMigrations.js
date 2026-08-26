.pragma library

function clone(value) {
    return value === undefined || value === null ? value : JSON.parse(JSON.stringify(value));
}

function migrateSettings(data) {
    if (!data || typeof data !== "object")
        return data;
    if (data.schemaVersion !== 1 && data.schemaVersion !== 2 && data.schemaVersion !== 3
            && data.schemaVersion !== 4 && data.schemaVersion !== 5)
        return clone(data);
    let current = clone(data);
    if (current.schemaVersion < 4 && (!current.modules || typeof current.modules !== "object" || Array.isArray(current.modules)))
        current.modules = {};
    if (current.schemaVersion === 1) {
        const legacyTheme = current.theme && typeof current.theme === "object" ? current.theme : {};
        const legacyAccessibility = current.accessibility && typeof current.accessibility === "object"
            ? current.accessibility : {};
        const legacyModules = current.modules && typeof current.modules === "object"
            && !Array.isArray(current.modules) ? current.modules : {};
        current = {
            "$schema": "titonium.settings/v2",
            "schemaVersion": 2,
            "locale": current.locale === "en" ? "en" : "vi",
            "appearance": {
                "themeId": "titonium-neutral",
                "mode": legacyTheme.mode === "light" ? "light" : "dark",
                "density": "comfortable",
                "overrides": {}
            },
            "accessibility": { "reducedMotion": legacyAccessibility.reducedMotion === true },
            "modules": clone(legacyModules)
        };
    }
    if (current.schemaVersion === 2) {
        const launcher = current.modules?.launcher;
        if (launcher && typeof launcher === "object" && !Array.isArray(launcher)) {
            current.modules.launcher = {
                "username": typeof launcher.username === "string" ? launcher.username : "",
                "avatarIcon": launcher.avatarIcon || "terminal",
                "pageTransition": launcher.pageTransition || "slide-fade",
                "transitionDuration": Number.isInteger(launcher.transitionDuration)
                    ? launcher.transitionDuration : 220
            };
        }
        current.$schema = "titonium.settings/v3";
        current.schemaVersion = 3;
    }
    if (current.schemaVersion === 3) {
        const launcher = current.modules?.launcher || {};
        current.modules.spotlight = {
            "pageTransition": launcher.pageTransition || "slide-fade",
            "transitionDuration": Number.isInteger(launcher.transitionDuration)
                ? launcher.transitionDuration : 220
        };
        delete current.modules.launcher;
        current.$schema = "titonium.settings/v4";
        current.schemaVersion = 4;
    }
    if (current.schemaVersion === 4) {
        current.applications = { "hiddenIds": [] };
        current.$schema = "titonium.settings/v5";
        current.schemaVersion = 5;
    }
    return current;
}

function migrateLayout(data) {
    const current = clone(data);
    if (!current || current.schemaVersion !== 1)
        return current;
    const screens = current.menubar?.screens;
    const defaultSlots = screens?.default?.slots;
    if (!defaultSlots || !Array.isArray(defaultSlots.start) || !Array.isArray(defaultSlots.center))
        return current;

    const workspaceIndex = defaultSlots.start.findIndex(node =>
        node?.type === "widget" && node.widgetType === "menubar.workspaces");
    const activeIndex = defaultSlots.center.findIndex(node =>
        node?.type === "widget" && node.widgetType === "menubar.active-window");
    if (workspaceIndex < 0 || activeIndex < 0)
        return current;

    const workspaceNode = defaultSlots.start[workspaceIndex];
    const activeNode = defaultSlots.center[activeIndex];
    activeNode.props = Object.assign({}, activeNode.props || {}, {
        "maximumWidth": Math.max(560, Number(activeNode.props?.maximumWidth || 0)),
        "activeMaximumWidth": 240
    });
    defaultSlots.start.splice(workspaceIndex, 1, {
        "id": "menubar-window-context",
        "type": "group",
        "padding": 0,
        "spacing": 0,
        "surface": false,
        "children": [workspaceNode, activeNode]
    });
    defaultSlots.center.splice(activeIndex, 1);

    Object.keys(screens).forEach(screenName => {
        if (screenName === "default")
            return;
        const center = screens[screenName]?.slots?.center;
        if (Array.isArray(center))
            screens[screenName].slots.center = center.filter(node =>
                !(node?.type === "widget" && node.widgetType === "menubar.active-window"));
    });
    return current;
}
