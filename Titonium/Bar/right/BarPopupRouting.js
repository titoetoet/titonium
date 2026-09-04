.pragma library

function normalizeStyle(value) {
    return value === "classic" ? "classic" : "connected";
}

function canToggle(ownerId, invoker, requiresInvoker) {
    if (!ownerId)
        return false;
    return requiresInvoker !== true || (invoker !== null && invoker !== undefined);
}

function existingOpenAction(requestOwnerId, managerOwnerId, barConnected,
        connectedOwnerId, connectedClosing, classicClosing) {
    if (!requestOwnerId || requestOwnerId !== managerOwnerId)
        return "open";
    if (barConnected === true && connectedOwnerId === requestOwnerId
            && connectedClosing === true)
        return "reverse";
    if (barConnected !== true && classicClosing === true)
        return "replace";
    return "preserve";
}

function styleAfterCleanup(currentStyle, requestedStyle, cleanup) {
    const current = normalizeStyle(currentStyle);
    const next = normalizeStyle(requestedStyle);
    if (current === next)
        return current;
    if (typeof cleanup !== "function")
        return current;
    cleanup();
    return next;
}

function presentation(style, feature) {
    const routes = normalizeStyle(style) === "classic" ? {
        network: ["overlay", "ClassicNetworkPopupSurface.qml", ""],
        bluetooth: ["overlay", "ClassicBluetoothPopupSurface.qml", ""],
        audio: ["overlay", "ClassicAudioPopupSurface.qml", ""],
        input: ["overlay", "ClassicSystemTrayPopupSurface.qml", ""],
        app: ["overlay", "ClassicSystemTrayPopupSurface.qml", ""],
    } : {
        network: ["edge", "ConnectedNetworkPopupContent.qml", "network"],
        bluetooth: ["edge", "ConnectedBluetoothPopupContent.qml", "bluetooth"],
        audio: ["edge", "ConnectedAudioPopupContent.qml", "audio"],
        input: ["edge", "SystemTrayMenuView.qml", "input"],
        app: ["edge", "SystemTrayMenuView.qml", "app"],
    };
    const route = routes[feature];
    return route ? { owner: route[0], source: route[1], anchor: route[2] } : null;
}
