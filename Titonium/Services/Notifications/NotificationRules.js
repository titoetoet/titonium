.pragma library

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function trimmedText(value) {
    return typeof value === "string" ? value.trim() : "";
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
    const source = actionSequence(value);
    const result = [];
    for (let index = 0; index < source.length; index++) {
        const candidate = source[index];
        if (!candidate || typeof candidate !== "object")
            continue;
        const id = actionIdentifier(candidate);
        if (!id)
            continue;
        result.push(Object.freeze({
            id: id,
            label: text(candidate.label) || text(candidate.text),
        }));
    }
    return Object.freeze(result);
}

function actionSequence(value) {
    if (Array.isArray(value))
        return value;
    if (!value || typeof value !== "object")
        return [];
    const length = Number(value.length);
    if (!Number.isInteger(length) || length < 0 || length > 64)
        return [];
    return value;
}

function actionIdentifier(candidate) {
    if (!candidate || typeof candidate !== "object")
        return "";
    const values = [candidate.id, candidate.identifier];
    for (let index = 0; index < values.length; index++) {
        if (typeof values[index] === "string" && values[index].length > 0)
            return values[index];
    }
    return "";
}

function nativeActions(notification) {
    const source = notification && typeof notification === "object"
        ? notification.actions : [];
    return actions(source);
}

function descriptor(raw, receivedAt) {
    const source = raw && typeof raw === "object" ? raw : {};
    const internal = source.source === "internal";
    const id = internal ? 0 : positiveId(source.id);
    const key = internal ? trimmedText(source.key) : (id ? "native:" + id : "");
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
    const key = stableKey(item?.key);
    if (!item || !key)
        return Object.freeze(source.slice(0, maximum));
    const result = [item];
    for (let index = 0; index < source.length && result.length < maximum; index++) {
        if (stableKey(source[index]?.key) !== key)
            result.push(source[index]);
    }
    return Object.freeze(result);
}

function stableKey(value) {
    return trimmedText(value);
}

function addToast(keys, key, limit) {
    const source = Array.isArray(keys) ? keys : [];
    const targetKey = stableKey(key);
    const maximum = Number.isInteger(limit) && limit > 0 ? limit : toastLimit();
    if (!targetKey)
        return Object.freeze(source.slice(0, maximum));
    const result = [targetKey];
    for (let index = 0; index < source.length && result.length < maximum; index++) {
        const candidate = stableKey(source[index]);
        if (candidate && candidate !== targetKey)
            result.push(candidate);
    }
    return Object.freeze(result);
}

function removeKey(values, key) {
    const source = Array.isArray(values) ? values : [];
    const targetKey = stableKey(key);
    if (!targetKey)
        return Object.freeze(source.slice());
    return Object.freeze(source.filter(value => stableKey(
        typeof value === "object" ? value?.key : value) !== targetKey));
}

function removeKeys(values, keys) {
    const source = Array.isArray(values) ? values : [];
    const candidates = Array.isArray(keys) ? keys : [];
    const removals = {};
    for (let index = 0; index < candidates.length; index++) {
        const candidate = stableKey(typeof candidates[index] === "object"
            ? candidates[index]?.key : candidates[index]);
        if (candidate)
            removals[candidate] = true;
    }
    return Object.freeze(source.filter(value => removals[stableKey(
        typeof value === "object" ? value?.key : value)] !== true));
}

function markUnread(keys, key) {
    return addToast(keys, key, Number.MAX_SAFE_INTEGER);
}

function refreshState(state, item, toastsEnabled) {
    const source = state && typeof state === "object" ? state : {};
    if (!item || !stableKey(item.key))
        return Object.freeze({
            notifications: Object.freeze(Array.isArray(source.notifications)
                ? source.notifications.slice() : []),
            unreadKeys: Object.freeze(Array.isArray(source.unreadKeys)
                ? source.unreadKeys.slice() : []),
            toastKeys: Object.freeze(Array.isArray(source.toastKeys)
                ? source.toastKeys.slice() : []),
        });
    const notifications = upsert(source.notifications, item, historyLimit());
    const unreadKeys = markUnread(source.unreadKeys, item.key);
    const toastKeys = item.route === "toast" && toastsEnabled === true
        ? addToast(source.toastKeys, item.key, toastLimit())
        : removeKey(source.toastKeys, item.key);
    return Object.freeze({ notifications, unreadKeys, toastKeys });
}

function dismissState(state, key) {
    const source = state && typeof state === "object" ? state : {};
    return Object.freeze({
        notifications: removeKey(source.notifications, key),
        unreadKeys: removeKey(source.unreadKeys, key),
        toastKeys: removeKey(source.toastKeys, key),
    });
}

function closeReason(value) {
    if (["expired", "dismissed", "close-requested"].indexOf(value) >= 0)
        return value;
    const reason = Number(value);
    if (reason === 0)
        return "expired";
    if (reason === 1)
        return "dismissed";
    return "close-requested";
}

function retireDescriptor(descriptor) {
    const result = {};
    for (const name in descriptor)
        result[name] = descriptor[name];
    result.actions = Object.freeze([]);
    return Object.freeze(result);
}

function retireState(state, key, reason) {
    const source = state && typeof state === "object" ? state : {};
    if (closeReason(reason) === "dismissed")
        return dismissState(source, key);
    const targetKey = stableKey(key);
    const notifications = Array.isArray(source.notifications)
        ? source.notifications.map(item => stableKey(item?.key) === targetKey
            ? retireDescriptor(item) : item) : [];
    return Object.freeze({
        notifications: Object.freeze(notifications),
        unreadKeys: Object.freeze(Array.isArray(source.unreadKeys)
            ? source.unreadKeys.slice() : []),
        toastKeys: removeKey(source.toastKeys, key),
    });
}

function clearState() {
    return Object.freeze({
        notifications: Object.freeze([]),
        unreadKeys: Object.freeze([]),
        toastKeys: Object.freeze([]),
    });
}

function warningState(counts, category, limit) {
    const source = counts && typeof counts === "object" ? counts : {};
    const key = typeof category === "string" ? category : "";
    const maximum = Number.isInteger(limit) && limit > 0 ? limit : 1;
    const current = Number.isInteger(source[key]) && source[key] >= 0 ? source[key] : 0;
    if (!key || current >= maximum)
        return Object.freeze({ counts: Object.freeze(Object.assign({}, source)), warn: false });
    const next = Object.assign({}, source);
    next[key] = current + 1;
    return Object.freeze({ counts: Object.freeze(next), warn: true });
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
