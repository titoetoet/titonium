.pragma library

function normalizedId(value) {
    return typeof value === "string" ? value.trim() : "";
}

function keyForId(value) {
    return normalizedId(value).toLocaleLowerCase();
}

function uniqueIds(values) {
    const source = Array.isArray(values) ? values : [];
    const seen = {};
    const result = [];
    for (let index = 0; index < source.length; index++) {
        const id = normalizedId(source[index]);
        const key = keyForId(id);
        if (!id || seen[key])
            continue;
        seen[key] = true;
        result.push(id);
    }
    return result;
}

function normalizeState(raw) {
    const source = raw && typeof raw === "object" ? raw : {};
    return {
        $schema: "titonium.dock/v1",
        schemaVersion: 1,
        pinnedIds: uniqueIds(source.pinnedIds),
        pinnedOpen: source.pinnedOpen === true,
        autoHide: source.autoHide !== false,
    };
}

function entryForId(entriesById, appId) {
    const entries = entriesById && typeof entriesById === "object" ? entriesById : {};
    if (entries[appId])
        return entries[appId];
    const targetKey = keyForId(appId);
    const keys = Object.keys(entries);
    for (let index = 0; index < keys.length; index++) {
        if (keyForId(keys[index]) === targetKey)
            return entries[keys[index]];
    }
    return null;
}

function combinedGroups(runningGroups) {
    const source = Array.isArray(runningGroups) ? runningGroups : [];
    const byId = {};
    const order = [];
    for (let index = 0; index < source.length; index++) {
        const group = source[index] || {};
        const appId = normalizedId(group.appId);
        const key = keyForId(appId);
        if (!appId)
            continue;
        if (!byId[key]) {
            byId[key] = { appId: appId, runningCount: 0, active: false, urgent: false };
            order.push(key);
        }
        byId[key].runningCount += Math.max(0, Number(group.runningCount) || 0);
        byId[key].active = byId[key].active || group.active === true;
        byId[key].urgent = byId[key].urgent || group.urgent === true;
    }
    return { byId: byId, order: order };
}

function itemFor(appId, group, entriesById, pinned) {
    const entry = entryForId(entriesById, appId) || {};
    return {
        appId: appId,
        name: normalizedId(entry.name) || appId || "Application",
        icon: normalizedId(entry.icon),
        runningCount: group ? group.runningCount : 0,
        active: group ? group.active : false,
        urgent: group ? group.urgent : false,
        pinned: pinned,
    };
}

function mergeItems(pinnedIds, runningGroups, entriesById, firstSeenIds) {
    const groups = combinedGroups(runningGroups);
    const pinned = uniqueIds(pinnedIds);
    const emitted = {};
    const result = [];

    for (let index = 0; index < pinned.length; index++) {
        const appId = pinned[index];
        const key = keyForId(appId);
        const group = groups.byId[key];
        const entry = entryForId(entriesById, appId);
        if (!group && !entry)
            continue;
        result.push(itemFor(appId, group, entriesById, true));
        emitted[key] = true;
    }

    const firstSeen = uniqueIds(firstSeenIds);
    for (let index = 0; index < firstSeen.length; index++) {
        const appId = firstSeen[index];
        const key = keyForId(appId);
        const group = groups.byId[key];
        if (!group || emitted[key])
            continue;
        result.push(itemFor(appId, group, entriesById, false));
        emitted[key] = true;
    }

    for (let index = 0; index < groups.order.length; index++) {
        const key = groups.order[index];
        if (emitted[key])
            continue;
        const group = groups.byId[key];
        result.push(itemFor(group.appId, group, entriesById, false));
        emitted[key] = true;
    }
    return result;
}

function nextCycleIndex(previousIndex, count) {
    const safeCount = Math.max(0, Math.floor(Number(count) || 0));
    if (safeCount === 0)
        return -1;
    const previous = Math.floor(Number(previousIndex));
    return Number.isFinite(previous) && previous >= 0 && previous < safeCount
        ? (previous + 1) % safeCount : 0;
}

function shouldReveal(autoHide, pinnedOpen, activeWorkspaceWindowCount, edgeHovered, dockHovered) {
    return pinnedOpen === true || autoHide !== true
        || Math.max(0, Number(activeWorkspaceWindowCount) || 0) === 0
        || edgeHovered === true || dockHovered === true;
}
