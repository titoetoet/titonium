.pragma library

const entries = Object.freeze([
    Object.freeze({ id: "general", icon: "tune", labelKey: "settings.nav.general" }),
    Object.freeze({ id: "appearance", icon: "palette", labelKey: "settings.nav.appearance" }),
    Object.freeze({ id: "spotlight", icon: "rocket_launch", labelKey: "settings.nav.spotlight" }),
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
