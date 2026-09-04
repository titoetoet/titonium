.pragma library

var READABLE_MS = 4000;

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function key(value) {
    return typeof value === "string" ? value.trim() : "";
}

function contextId(descriptor) {
    var notificationKey = key(descriptor && descriptor.key);
    return notificationKey ? "notification:" + notificationKey : "";
}

function actionCapabilityId(actionId) {
    var id = key(actionId);
    return id ? "notification.action:" + encodeURIComponent(id) : "";
}

function context(descriptor) {
    var id = contextId(descriptor);
    if (!id)
        return null;
    var title = text(descriptor.summary) || text(descriptor.body)
        || text(descriptor.appName) || "Notification";
    var actionIds = [];
    var sourceActions = Array.isArray(descriptor.actions) ? descriptor.actions : [];
    for (var index = 0; index < sourceActions.length; index++) {
        var capabilityId = actionCapabilityId(sourceActions[index] && sourceActions[index].id);
        if (capabilityId && actionIds.indexOf(capabilityId) < 0)
            actionIds.push(capabilityId);
    }
    actionIds.push("notification.dismiss");
    return Object.freeze({
        id: id,
        source: "notification",
        kind: "notification",
        title: title,
        subtitle: text(descriptor.body) || text(descriptor.appName),
        icon: text(descriptor.appIcon) || "notifications",
        tone: "critical",
        attention: "transient",
        progress: null,
        occurredAt: Number.isFinite(descriptor.receivedAt) ? descriptor.receivedAt : 0,
        expiresAt: 0,
        details: Object.freeze({
            notificationKey: key(descriptor.key),
            appName: text(descriptor.appName),
            body: text(descriptor.body),
            category: text(descriptor.category) || "notification",
        }),
        actionIds: Object.freeze(actionIds),
    });
}

function capabilities(descriptor, id) {
    var contextValue = id || contextId(descriptor);
    if (!contextValue)
        return Object.freeze([]);
    var result = [];
    var seen = {};
    var sourceActions = Array.isArray(descriptor && descriptor.actions)
        ? descriptor.actions : [];
    for (var index = 0; index < sourceActions.length; index++) {
        var source = sourceActions[index];
        var actionId = actionCapabilityId(source && source.id);
        if (!actionId || seen[actionId])
            continue;
        seen[actionId] = true;
        result.push(Object.freeze({
            id: actionId,
            contextId: contextValue,
            role: "primary",
            label: text(source.label) || "Open",
            icon: "open_in_new",
            enabled: true,
        }));
    }
    result.push(Object.freeze({
        id: "notification.dismiss",
        contextId: contextValue,
        role: "destructive",
        label: "Dismiss",
        icon: "close",
        enabled: true,
    }));
    return Object.freeze(result);
}

function presentation(descriptor) {
    var id = contextId(descriptor);
    if (!id)
        return null;
    return Object.freeze({
        id: id + ":presentation",
        source: "notification",
        contextId: id,
        requestedMode: "banner",
        attention: "transient",
        timeoutMs: READABLE_MS,
        focusPolicy: "none",
    });
}

function actionIntent(actionId, selectedContextId) {
    var id = key(actionId);
    var contextValue = key(selectedContextId);
    if (contextValue.indexOf("notification:") !== 0)
        return null;
    var notificationKey = contextValue.slice("notification:".length);
    if (!notificationKey)
        return null;
    if (id === "notification.dismiss")
        return Object.freeze({ kind: "dismiss", key: notificationKey, actionId: "" });
    var prefix = "notification.action:";
    if (id.indexOf(prefix) !== 0)
        return null;
    var nativeActionId = "";
    try {
        nativeActionId = decodeURIComponent(id.slice(prefix.length));
    } catch (failure) {
        return null;
    }
    if (!nativeActionId)
        return null;
    return Object.freeze({
        kind: "action",
        key: notificationKey,
        actionId: nativeActionId,
    });
}
