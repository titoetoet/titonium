.pragma library

function screenName(value) {
    return typeof value === "string" ? value.trim() : "";
}

function ownerId(value) {
    var name = screenName(value);
    return name ? "notification-panel:" + name : "";
}

function toggleAction(currentOwnerId, requestedOwnerId) {
    if (!requestedOwnerId)
        return "reject";
    if (currentOwnerId === requestedOwnerId)
        return "close";
    return currentOwnerId ? "replace" : "open";
}
