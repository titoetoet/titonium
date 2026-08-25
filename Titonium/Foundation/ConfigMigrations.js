.pragma library

function clone(value) {
    return value === undefined || value === null ? value : JSON.parse(JSON.stringify(value));
}

function migrateSettings(data) {
    if (!data || typeof data !== "object")
        return data;
    if (data.schemaVersion === 2) {
        const current = clone(data);
        if (current.modules?.launcher?.defaultCategory === "favorites")
            current.modules.launcher.defaultCategory = "all";
        return current;
    }
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
