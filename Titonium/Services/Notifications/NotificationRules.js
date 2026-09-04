.pragma library

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function positiveId(value) {
    return Number.isInteger(value) && value > 0 ? value : 0;
}

function nativeUrgency(value) {
    const urgency = Number(value);
    if (!Number.isInteger(urgency))
        return "normal";
    if (urgency <= 0)
        return "low";
    return urgency >= 2 ? "critical" : "normal";
}

function historyLimit() {
    return 100;
}

function toastLimit() {
    return 3;
}

function criticalQueueLimit() {
    return 16;
}

function nativeSeverity(urgency) {
    return urgency === "critical" ? "critical" : "normal";
}

function routeForSeverity(severity) {
    return severity === "critical" ? "center" : "toast";
}

function actions(value) {
    const source = Array.isArray(value) ? value : [];
    const result = [];
    for (let index = 0; index < source.length; index++) {
        const candidate = source[index];
        if (!candidate || typeof candidate !== "object")
            continue;
        const id = text(candidate.id);
        if (!id)
            continue;
        result.push(Object.freeze({ id: id, label: text(candidate.label) }));
    }
    return Object.freeze(result);
}

function descriptor(raw, receivedAt) {
    const source = raw && typeof raw === "object" ? raw : {};
    const internal = source.source === "internal";
    const id = internal ? 0 : positiveId(source.id);
    const key = internal ? text(source.key) : (id ? "native:" + id : "");
    if (!key || (internal && key.indexOf("internal:") !== 0))
        return null;
    const timestamp = Number(receivedAt);
    const urgency = Number.isInteger(Number(source.urgency))
        ? Math.max(0, Math.min(2, Number(source.urgency))) : 1;
    const normalizedUrgency = nativeUrgency(urgency);
    const category = text(source.category) || (internal
        ? (text(source.kind).indexOf("timer_") === 0 ? "timer" : "job")
        : "notification");
    const severity = nativeSeverity(normalizedUrgency);
    const result = {
        id: id,
        key: key,
        source: internal ? "internal" : "native",
        appId: text(source.appId) || (internal ? "" : text(source.appName)),
        appName: text(source.appName),
        appIcon: text(source.appIcon),
        summary: text(source.summary),
        body: text(source.body),
        urgency: urgency,
        nativeUrgency: normalizedUrgency,
        severity: severity,
        route: routeForSeverity(severity),
        category: category,
        actions: actions(source.actions),
        receivedAt: Number.isFinite(timestamp) ? timestamp : 0,
    };
    if (!id)
        delete result.id;
    return Object.freeze(result);
}

function notificationPreferences(preferences) {
    const modules = preferences && typeof preferences === "object"
        && preferences.modules && typeof preferences.modules === "object"
        ? preferences.modules : {};
    return modules.notifications && typeof modules.notifications === "object"
        ? modules.notifications : {};
}

function overrideFor(descriptor, preferences) {
    const settings = notificationPreferences(preferences);
    if (settings.policyMode !== "custom" || descriptor.source !== "native" || !descriptor.appId)
        return "follow";
    const overrides = settings.applicationOverrides && typeof settings.applicationOverrides === "object"
        ? settings.applicationOverrides : {};
    const value = overrides[descriptor.appId];
    return ["follow", "quiet", "normal", "critical", "block"].indexOf(value) >= 0
        ? value : "follow";
}

function policyResult(descriptor, severity, route) {
    const result = {};
    for (const key in descriptor)
        result[key] = descriptor[key];
    result.severity = severity;
    result.route = route;
    return Object.freeze(result);
}

function routeForPolicySeverity(severity, preferences) {
    const settings = notificationPreferences(preferences);
    if (severity === "critical" && settings.allowCriticalOnIsland === false)
        return "history";
    return routeForSeverity(severity);
}

function resolvePolicy(value, preferences) {
    if (!value || typeof value !== "object")
        return null;
    const descriptorValue = value;
    const override = overrideFor(descriptorValue, preferences);
    if (override === "block")
        return policyResult(descriptorValue, "normal", "block");
    if (override === "quiet")
        return policyResult(descriptorValue, "normal", "history");
    if (override === "normal")
        return policyResult(descriptorValue, "normal", "toast");
    if (override === "critical")
        return policyResult(descriptorValue, "critical",
            routeForPolicySeverity("critical", preferences));

    const internalCritical = descriptorValue.source === "internal"
        && /^(?:internal:job_failed:|internal:job_requires_action:|internal:timer_finished:)/
            .test(descriptorValue.key);
    const severity = internalCritical ? "critical"
        : nativeSeverity(descriptorValue.nativeUrgency);
    const route = routeForPolicySeverity(severity, preferences);
    return policyResult(descriptorValue, severity, route);
}

function upsert(list, item, limit) {
    const source = Array.isArray(list) ? list : [];
    const maximum = Number.isInteger(limit) && limit > 0 ? limit : historyLimit();
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
    const maximum = Number.isInteger(limit) && limit > 0 ? limit : toastLimit();
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
        title: screenshot ? title : (text(item.summary) || text(item.body) || text(title)),
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
