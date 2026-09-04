.pragma library

var SOURCES = Object.freeze({
    capture: true, media: true, notification: true, agent: true,
    focus: true, timer: true, job: true
});
var TONES = Object.freeze({
    neutral: true, normal: true, positive: true, warning: true, critical: true
});
var ATTENTION = Object.freeze({ ambient: true, transient: true, blocking: true });
var ROLES = Object.freeze({ primary: true, secondary: true, destructive: true });
var STATUSES = Object.freeze({
    completed: true, pending: true, rejected: true, stale: true, unavailable: true
});
var CLOSE_POLICIES = Object.freeze({ keep: true, compact: true, dismiss: true });
var CONTEXT_FIELDS = Object.freeze({
    id: true, source: true, kind: true, title: true, subtitle: true,
    icon: true, tone: true, attention: true, progress: true,
    occurredAt: true, expiresAt: true, details: true, actionIds: true
});

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function hasOnly(raw, allowlist) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return false;
    var keys = Object.keys(raw);
    for (var index = 0; index < keys.length; index++) {
        if (!allowlist[keys[index]])
            return false;
    }
    return true;
}

function frozenValue(value) {
    if (Array.isArray(value)) {
        var array = [];
        for (var index = 0; index < value.length; index++)
            array.push(frozenValue(value[index]));
        return Object.freeze(array);
    }
    if (value && typeof value === "object") {
        var result = {};
        var keys = Object.keys(value).sort();
        for (var keyIndex = 0; keyIndex < keys.length; keyIndex++) {
            var member = value[keys[keyIndex]];
            if (typeof member === "function" || typeof member === "undefined")
                return null;
            result[keys[keyIndex]] = frozenValue(member);
            if (result[keys[keyIndex]] === null && member !== null)
                return null;
        }
        return Object.freeze(result);
    }
    if (["string", "number", "boolean"].indexOf(typeof value) >= 0 || value === null)
        return value;
    return null;
}

function normalizeContext(raw, now) {
    if (!hasOnly(raw, CONTEXT_FIELDS))
        return null;
    var id = text(raw.id);
    var source = text(raw.source);
    var kind = text(raw.kind);
    var title = text(raw.title);
    var subtitle = text(raw.subtitle);
    var icon = text(raw.icon);
    var tone = text(raw.tone);
    var attention = text(raw.attention);
    var occurredAt = Number(raw.occurredAt);
    var expiresAt = Number(raw.expiresAt);
    var progress = raw.progress === null ? null : Number(raw.progress);
    if (!id || id.indexOf(source + ":") !== 0 || !SOURCES[source] || !kind || !title
            || !icon || !TONES[tone] || !ATTENTION[attention]
            || !Number.isFinite(occurredAt) || occurredAt < 0
            || !Number.isFinite(expiresAt) || expiresAt < 0
            || (expiresAt > 0 && expiresAt <= Number(now))
            || (progress !== null && (!Number.isFinite(progress) || progress < 0 || progress > 1))
            || !Array.isArray(raw.actionIds))
        return null;
    var details = frozenValue(raw.details || {});
    if (details === null)
        return null;
    var actionIds = [];
    for (var index = 0; index < raw.actionIds.length; index++) {
        var actionId = text(raw.actionIds[index]);
        if (!actionId || actionIds.indexOf(actionId) >= 0)
            return null;
        actionIds.push(actionId);
    }
    return Object.freeze({
        id: id, source: source, kind: kind, title: title, subtitle: subtitle,
        icon: icon, tone: tone, attention: attention, progress: progress,
        occurredAt: occurredAt, expiresAt: expiresAt, details: details,
        actionIds: Object.freeze(actionIds)
    });
}

function normalizeIndicator(raw) {
    var allowlist = { id: true, icon: true, accessibleName: true, tone: true, active: true,
        count: true, revision: true };
    if (!hasOnly(raw, allowlist))
        return null;
    var id = text(raw.id);
    var icon = text(raw.icon);
    var accessibleName = text(raw.accessibleName);
    var tone = text(raw.tone);
    var hasCount = Object.prototype.hasOwnProperty.call(raw, "count");
    var hasRevision = Object.prototype.hasOwnProperty.call(raw, "revision");
    var count = Number(raw.count);
    var revision = Number(raw.revision);
    if (!id || !icon || !accessibleName || !TONES[tone] || typeof raw.active !== "boolean"
            || (hasCount && (!Number.isInteger(count) || count < 0))
            || (hasRevision && (!Number.isInteger(revision) || revision < 0)))
        return null;
    var result = { id: id, icon: icon, accessibleName: accessibleName,
        tone: tone, active: raw.active };
    if (hasCount)
        result.count = count;
    if (hasRevision)
        result.revision = revision;
    return Object.freeze(result);
}

function normalizeCapability(raw, contextIds) {
    var allowlist = { id: true, contextId: true, role: true, label: true,
        icon: true, enabled: true };
    if (!hasOnly(raw, allowlist))
        return null;
    var id = text(raw.id);
    var contextId = text(raw.contextId);
    var role = text(raw.role);
    var label = text(raw.label);
    var icon = text(raw.icon);
    if (!id || !contextId || contextIds.indexOf(contextId) < 0 || !ROLES[role]
            || !label || !icon || typeof raw.enabled !== "boolean")
        return null;
    return Object.freeze({ id: id, contextId: contextId, role: role,
        label: label, icon: icon, enabled: raw.enabled });
}

function contextRank(value) {
    var attentionRank = value.attention === "blocking" ? 300
        : (value.attention === "transient" ? 200 : 0);
    var sourceRank = value.source === "focus" ? 70
        : (value.source === "media" ? 60
        : (value.source === "timer" ? 50
        : (value.source === "job" ? 40
        : (value.source === "capture" ? 30
        : (value.source === "agent" ? 20 : 10)))));
    return attentionRank + sourceRank;
}

function orderContexts(values) {
    values.sort(function(left, right) {
        var rank = contextRank(right) - contextRank(left);
        if (rank !== 0)
            return rank;
        if (left.occurredAt !== right.occurredAt)
            return right.occurredAt - left.occurredAt;
        return left.id < right.id ? -1 : (left.id > right.id ? 1 : 0);
    });
    return values;
}

function semanticValue(value) {
    return JSON.stringify(value, function(key, member) {
        return key === "revision" ? undefined : member;
    });
}

function snapshot(previous, raw, now) {
    var input = raw && typeof raw === "object" ? raw : {};
    var contexts = [];
    var sourceContexts = Array.isArray(input.contexts) ? input.contexts : [];
    for (var index = 0; index < sourceContexts.length; index++) {
        var normalizedContext = normalizeContext(sourceContexts[index], now);
        if (normalizedContext)
            contexts.push(normalizedContext);
    }
    orderContexts(contexts);
    var contextIds = contexts.map(function(value) { return value.id; });
    var indicators = [];
    var sourceIndicators = Array.isArray(input.indicators) ? input.indicators : [];
    for (var indicatorIndex = 0; indicatorIndex < sourceIndicators.length; indicatorIndex++) {
        var indicator = normalizeIndicator(sourceIndicators[indicatorIndex]);
        if (indicator)
            indicators.push(indicator);
    }
    var actions = [];
    var sourceActions = Array.isArray(input.actions) ? input.actions : [];
    for (var actionIndex = 0; actionIndex < sourceActions.length; actionIndex++) {
        var action = normalizeCapability(sourceActions[actionIndex], contextIds);
        if (action)
            actions.push(action);
    }
    var result = Object.freeze({
        revision: previous && Number.isFinite(previous.revision) ? previous.revision + 1 : 1,
        primary: contexts.length > 0 ? contexts[0] : null,
        secondary: contexts.length > 1 ? contexts[1] : null,
        contexts: Object.freeze(contexts),
        indicators: Object.freeze(indicators),
        capabilities: Object.freeze({ actions: Object.freeze(actions) })
    });
    if (previous && semanticValue(previous) === semanticValue(result))
        return previous;
    return result;
}

function actionResult(raw) {
    var valid = raw && typeof raw === "object" && typeof raw.accepted === "boolean"
        && STATUSES[raw.status] && CLOSE_POLICIES[raw.closePolicy];
    if (!valid)
        return Object.freeze({ accepted: false, status: "rejected",
            reason: "invalid-result", closePolicy: "keep" });
    return Object.freeze({ accepted: raw.accepted, status: raw.status,
        reason: text(raw.reason), closePolicy: raw.closePolicy });
}
