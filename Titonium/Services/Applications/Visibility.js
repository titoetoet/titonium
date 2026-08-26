.pragma library

function normalizeHidden(hiddenIds) {
    const source = Array.isArray(hiddenIds) ? hiddenIds : [];
    const seen = Object.create(null);
    const result = [];
    for (let index = 0; index < source.length; index++) {
        const entryId = source[index];
        if (typeof entryId !== "string" || entryId.length === 0)
            continue;
        const key = "$" + entryId;
        if (!seen[key]) {
            seen[key] = true;
            result.push(entryId);
        }
    }
    return result;
}

function membership(hiddenIds) {
    const result = Object.create(null);
    normalizeHidden(hiddenIds).forEach(id => result["$" + id] = true);
    return result;
}

function filterVisible(apps, hiddenIds) {
    const hidden = membership(hiddenIds);
    return (Array.isArray(apps) ? apps : [])
        .filter(app => app && typeof app.id === "string" && !hidden["$" + app.id]);
}

function isVisible(hiddenIds, entryId) {
    return typeof entryId === "string" && entryId.length > 0
        && !membership(hiddenIds)["$" + entryId];
}

function setVisible(hiddenIds, entryId, visible) {
    const hidden = normalizeHidden(hiddenIds);
    if (typeof entryId !== "string" || entryId.length === 0)
        return hidden;
    const filtered = hidden.filter(id => id !== entryId);
    if (visible !== true)
        filtered.push(entryId);
    return filtered;
}
