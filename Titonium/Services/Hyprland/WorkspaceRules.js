.pragma library

function positiveInteger(value, fallback) {
    const numeric = Number(value);
    return Number.isInteger(numeric) && numeric > 0 ? numeric : fallback;
}

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function monitorByName(monitors, screenName) {
    const source = monitors && typeof monitors.length === "number" ? monitors : [];
    const target = text(screenName);
    if (!target)
        return null;
    for (let index = 0; index < source.length; index++) {
        if (text(source[index]?.name) === target)
            return source[index];
    }
    return null;
}

function focusedWorkspaceId(monitors, fallback) {
    const source = monitors && typeof monitors.length === "number" ? monitors : [];
    for (let index = 0; index < source.length; index++) {
        const monitor = source[index];
        if (monitor?.focused !== true)
            continue;
        const workspaceId = positiveInteger(monitor?.activeWorkspace?.id, 0);
        if (workspaceId > 0)
            return workspaceId;
    }
    return positiveInteger(fallback, 1);
}

function focusedMonitorWorkspaceId(monitors, monitorName, fallback) {
    const monitor = monitorByName(monitors, monitorName);
    return positiveInteger(monitor?.activeWorkspace?.id, positiveInteger(fallback, 0));
}

function focusedWorkspaceEventId(eventName, fields) {
    const source = fields && typeof fields.length === "number" ? fields : [];
    if (eventName === "focusedmon" || eventName === "focusedmonv2")
        return positiveInteger(source[1], 0);
    if (eventName === "workspace" || eventName === "workspacev2")
        return positiveInteger(source[0], 0);
    return 0;
}

function groupStart(activeId, count) {
    const size = Math.max(1, Math.min(10, positiveInteger(count, 5)));
    const active = positiveInteger(activeId, 1);
    return Math.floor((active - 1) / size) * size + 1;
}

function project(activeId, count, nativeStates, windows) {
    const size = Math.max(1, Math.min(10, positiveInteger(count, 5)));
    const active = positiveInteger(activeId, 1);
    const start = groupStart(active, size);
    const facts = Array.isArray(nativeStates) ? nativeStates : [];
    const windowSource = Array.isArray(windows) ? windows : [];
    const factsById = {};
    const appsByWorkspace = {};
    const appKeysByWorkspace = {};
    const result = [];

    for (let index = 0; index < facts.length; index++) {
        const id = positiveInteger(facts[index]?.id, 0);
        if (id > 0 && !factsById[id])
            factsById[id] = facts[index];
    }
    for (let index = 0; index < windowSource.length; index++) {
        const window = windowSource[index] || {};
        const workspaceId = positiveInteger(window.workspaceId, 0);
        const appId = text(window.appId);
        const icon = text(window.icon);
        const appKey = appId.toLocaleLowerCase();
        if (workspaceId <= 0 || !appKey)
            continue;
        if (!appsByWorkspace[workspaceId]) {
            appsByWorkspace[workspaceId] = [];
            appKeysByWorkspace[workspaceId] = {};
        }
        if (appKeysByWorkspace[workspaceId][appKey])
            continue;
        appKeysByWorkspace[workspaceId][appKey] = true;
        appsByWorkspace[workspaceId].push(Object.freeze({ appId: appId, icon: icon,
            fallbackIcon: text(window.fallbackIcon) || "apps" }));
    }

    for (let offset = 0; offset < size; offset++) {
        const id = start + offset;
        const fact = factsById[id] || {};
        const apps = Object.freeze((appsByWorkspace[id] || []).slice());
        result.push({
            id: id,
            active: id === active,
            occupied: Boolean(fact.occupied) || apps.length > 0,
            urgent: Boolean(fact.urgent),
            apps: apps,
            colorIndex: id - 1,
            rangeStart: 0,
            rangeEnd: 0,
        });
    }

    let cursor = 0;
    while (cursor < result.length) {
        if (!result[cursor].occupied) {
            cursor += 1;
            continue;
        }
        const rangeStartIndex = cursor;
        while (cursor + 1 < result.length && result[cursor + 1].occupied)
            cursor += 1;
        const rangeStartId = result[rangeStartIndex].id;
        const rangeEndId = result[cursor].id;
        for (let index = rangeStartIndex; index <= cursor; index++) {
            result[index].rangeStart = rangeStartId;
            result[index].rangeEnd = rangeEndId;
        }
        cursor += 1;
    }

    for (let index = 0; index < result.length; index++)
        Object.freeze(result[index]);
    return Object.freeze(result);
}
