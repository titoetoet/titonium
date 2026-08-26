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
        if (seen[key])
            continue;
        seen[key] = true;
        result.push(entryId);
    }
    return result;
}

function membership(hiddenIds) {
    const hidden = normalizeHidden(hiddenIds);
    const result = Object.create(null);
    for (let index = 0; index < hidden.length; index++)
        result["$" + hidden[index]] = true;
    return result;
}

function filterVisible(apps, hiddenIds) {
    const source = Array.isArray(apps) ? apps : [];
    const hidden = membership(hiddenIds);
    return source.filter(app => app && typeof app.id === "string" && !hidden["$" + app.id]);
}

function isVisible(hiddenIds, entryId) {
    if (typeof entryId !== "string" || entryId.length === 0)
        return false;
    return !membership(hiddenIds)["$" + entryId];
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
