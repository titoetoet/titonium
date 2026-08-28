.pragma library

const entries = Object.freeze([
    Object.freeze({ id: "general", icon: "tune", labelKey: "settings.nav.general" }),
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
