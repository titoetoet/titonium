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

function presentation(style) {
    if (style === "classic")
        return { owner: "overlay", source: "ClassicNotificationPanel.qml", anchor: "" };
    return {
        owner: "edge",
        source: "ConnectedNotificationPanelContent.qml",
        anchor: "notifications",
    };
}
