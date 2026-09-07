.pragma library

const entries = Object.freeze([
    Object.freeze({ id: "general", icon: "tune", labelKey: "settings.nav.general" }),
    Object.freeze({ id: "appearance", icon: "palette", labelKey: "settings.nav.appearance" }),
    Object.freeze({ id: "spotlight", icon: "rocket_launch", labelKey: "settings.nav.spotlight" }),
    Object.freeze({ id: "bar", icon: "toolbar", labelKey: "settings.nav.bar" }),
    Object.freeze({ id: "dock", icon: "dock_to_bottom", labelKey: "settings.nav.dock" }),
    Object.freeze({ id: "notifications", icon: "notifications", labelKey: "settings.nav.notifications" }),
    Object.freeze({ id: "audio", icon: "volume_up", labelKey: "settings.nav.audio" }),
    Object.freeze({ id: "about", icon: "info", labelKey: "settings.nav.about" }),
]);

function navigationEntries() {
    return entries;
}

function pageIds() {
    return entries.map(entry => entry.id);
}

function normalizePage(pageId) {
    const normalized = typeof pageId === "string" ? pageId.trim().toLowerCase() : "";
    return pageIds().indexOf(normalized) >= 0 ? normalized : "general";
}

// Only paths owned by editable pages; unknown pages never reset General.
function resetPaths(pageId) {
    const paths = {
        general: ["locale", "accessibility"],
        appearance: ["appearance", "accessibility"],
        spotlight: ["modules.spotlight", "applications"],
        bar: ["modules.bar"], dock: ["modules.dock"],
        notifications: ["modules.notifications"], audio: ["modules.audio"]
    };
    return Object.prototype.hasOwnProperty.call(paths, pageId) ? paths[pageId].slice() : [];
}
