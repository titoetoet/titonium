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

function normalizeVisibilityMode(value) {
    return ["auto-hide", "always-visible", "reserve-space", "hidden"].indexOf(value) >= 0
        ? value : "auto-hide";
}

function visibilityPolicy(mode) {
    const normalized = normalizeVisibilityMode(mode);
    return {
        autoHide: normalized === "auto-hide",
        pinnedOpen: normalized === "reserve-space",
        hidden: normalized === "hidden",
    };
}

function movePinnedId(values, fromIndex, toIndex) {
    const result = uniqueIds(values);
    const source = Math.floor(Number(fromIndex));
    const target = Math.floor(Number(toIndex));
    if (!Number.isFinite(source) || !Number.isFinite(target)
            || source < 0 || source >= result.length || result.length < 2)
        return result;
    const boundedTarget = Math.max(0, Math.min(result.length - 1, target));
    if (source === boundedTarget)
        return result;
    const moved = result.splice(source, 1)[0];
    result.splice(boundedTarget, 0, moved);
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
            byId[key] = { appId: appId, runningCount: 0, active: false, urgent: false,
                activeWorkspaceId: 0 };
            order.push(key);
        }
        byId[key].runningCount += Math.max(0, Number(group.runningCount) || 0);
        byId[key].active = byId[key].active || group.active === true;
        byId[key].urgent = byId[key].urgent || group.urgent === true;
        if (group.active === true && Number.isInteger(group.activeWorkspaceId)
                && group.activeWorkspaceId > 0)
            byId[key].activeWorkspaceId = group.activeWorkspaceId;
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
        workspaceColorIndex: group && group.activeWorkspaceId > 0
            ? (group.activeWorkspaceId - 1) % 5 : -1,
    };
}

function canonicalUnpinnedId(group, entriesById) {
    const entry = entryForId(entriesById, group.appId) || {};
    return normalizedId(entry.id) || group.appId;
}

function mergeItems(pinnedIds, runningGroups, entriesById, firstSeenIds, hiddenIds) {
    const groups = combinedGroups(runningGroups);
    const pinned = uniqueIds(pinnedIds);
    const emitted = {};
    const hidden = {};
    const result = [];
    uniqueIds(hiddenIds).forEach(id => hidden[keyForId(id)] = true);

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
        if (!group || emitted[key] || hidden[key])
            continue;
        result.push(itemFor(canonicalUnpinnedId(group, entriesById), group, entriesById, false));
        emitted[key] = true;
    }

    for (let index = 0; index < groups.order.length; index++) {
        const key = groups.order[index];
        if (emitted[key] || hidden[key])
            continue;
        const group = groups.byId[key];
        result.push(itemFor(canonicalUnpinnedId(group, entriesById), group, entriesById, false));
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

function exclusiveZone(pinnedOpen, bodyHeight) {
    if (pinnedOpen !== true)
        return 0;
    return Math.max(0, Number(bodyHeight) || 0);
}
