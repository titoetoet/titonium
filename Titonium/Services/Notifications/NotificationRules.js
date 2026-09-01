.pragma library

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function positiveId(value) {
    return Number.isInteger(value) && value > 0 ? value : 0;
}

function descriptor(raw, receivedAt) {
    const source = raw && typeof raw === "object" ? raw : {};
    const id = positiveId(source.id);
    if (!id)
        return null;
    const timestamp = Number(receivedAt);
    const urgency = Number(source.urgency);
    return Object.freeze({
        id: id,
        appName: text(source.appName),
        appIcon: text(source.appIcon),
        summary: text(source.summary),
        body: text(source.body),
        urgency: Number.isInteger(urgency) ? Math.max(0, Math.min(2, urgency)) : 1,
        receivedAt: Number.isFinite(timestamp) ? timestamp : 0,
    });
}

function upsert(list, item, limit) {
    const source = Array.isArray(list) ? list : [];
    const maximum = Number.isInteger(limit) && limit > 0 ? limit : 100;
    if (!item || !positiveId(item.id))
        return Object.freeze(source.slice(0, maximum));
    const result = [item];
    for (let index = 0; index < source.length && result.length < maximum; index++) {
        if (positiveId(source[index]?.id) !== item.id)
            result.push(source[index]);
    }
    return Object.freeze(result);
}

function addToast(ids, id, limit) {
    const source = Array.isArray(ids) ? ids : [];
    const targetId = positiveId(id);
    const maximum = Number.isInteger(limit) && limit > 0 ? limit : 3;
    if (!targetId)
        return Object.freeze(source.slice(0, maximum));
    const result = [targetId];
    for (let index = 0; index < source.length && result.length < maximum; index++) {
        const candidate = positiveId(source[index]);
        if (candidate && candidate !== targetId)
            result.push(candidate);
    }
    return Object.freeze(result);
}

function removeId(values, id) {
    const source = Array.isArray(values) ? values : [];
    const targetId = positiveId(id);
    if (!targetId)
        return Object.freeze(source.slice());
    return Object.freeze(source.filter(value => {
        const candidate = typeof value === "object" ? value?.id : value;
        return positiveId(candidate) !== targetId;
    }));
}

function removeIds(values, ids) {
    const source = Array.isArray(values) ? values : [];
    const candidates = Array.isArray(ids) ? ids : [];
    const removals = {};
    for (let index = 0; index < candidates.length; index++) {
        const value = candidates[index];
        const candidate = typeof value === "object" ? value?.id : value;
        const id = positiveId(candidate);
        if (id)
            removals[String(id)] = true;
    }
    return Object.freeze(source.filter(value => {
        const candidate = typeof value === "object" ? value?.id : value;
        return removals[String(positiveId(candidate))] !== true;
    }));
}

function markUnread(ids, id) {
    return addToast(ids, id, Number.MAX_SAFE_INTEGER);
}

function centerEvent(item, title, now) {
    if (!item || !positiveId(item.id) || !text(title))
        return null;
    const screenshot = text(item.summary).toLowerCase() === "screenshot saved";
    return Object.freeze({
        id: screenshot ? "capture:screenshot" : "notification:new",
        deduplicationKey: screenshot ? "capture:screenshot" : "notification:new",
        source: screenshot ? "capture" : "notification",
        kind: screenshot ? "screenshot_saved" : "new",
        title: screenshot ? title : text(title),
        icon: screenshot ? "screenshot" : "notifications",
        createdAt: Number.isFinite(now) ? now : 0,
    });
}

function unreadIndicator(count, label) {
    return Object.freeze({
        id: "notification",
        icon: "mark_email_unread",
        accessibleName: text(label) || "Unread notifications",
        active: Number.isInteger(count) && count > 0,
    });
}

function unreadCount(ids) {
    return Array.isArray(ids) ? ids.length : 0;
}

function relativeAge(receivedAt, now) {
    const received = Number(receivedAt);
    const current = Number(now);
    if (!Number.isFinite(received) || !Number.isFinite(current)
            || received < 0 || received > current)
        return null;
    const age = current - received;
    if (age < 60000)
        return Object.freeze({ unit: "now", count: 0 });
    if (age < 3600000)
        return Object.freeze({ unit: "minutes", count: Math.floor(age / 60000) });
    if (age < 86400000)
        return Object.freeze({ unit: "hours", count: Math.floor(age / 3600000) });
    return Object.freeze({ unit: "days", count: Math.floor(age / 86400000) });
}
