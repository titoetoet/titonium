.pragma library

const entries = Object.freeze([
    Object.freeze({ id: "general", icon: "tune", labelKey: "settings.nav.general" }),
    Object.freeze({ id: "appearance", icon: "palette", labelKey: "settings.nav.appearance" }),
    Object.freeze({ id: "spotlight", icon: "rocket_launch", labelKey: "settings.nav.spotlight" }),
    Object.freeze({ id: "bar", icon: "toolbar", labelKey: "settings.nav.bar" }),
    Object.freeze({ id: "dock", icon: "dock_to_bottom", labelKey: "settings.nav.dock" }),
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
