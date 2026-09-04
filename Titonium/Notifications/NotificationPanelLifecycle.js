.pragma library

function ownerId(value) {
    return typeof value === "string" ? value.trim() : "";
}

function plan(mountedOwnerId, unmountOwnerId, mountOwnerId, markRead) {
    return Object.freeze({
        mountedOwnerId: mountedOwnerId,
        unmountOwnerId: unmountOwnerId,
        mountOwnerId: mountOwnerId,
        markRead: markRead === true,
    });
}

function transition(currentOwnerId, requestedOwnerId) {
    var current = ownerId(currentOwnerId);
    var requested = ownerId(requestedOwnerId);
    if (current === requested)
        return plan(current, "", "", false);
    return plan(requested, current, requested, requested.length > 0);
}

function teardown(currentOwnerId) {
    var current = ownerId(currentOwnerId);
    return plan("", current, "", false);
}
