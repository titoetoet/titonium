.pragma library

function normalizeStyle(value) {
    return value === "classic" ? "classic" : "connected";
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
