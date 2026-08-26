.pragma library

function descriptor(id, icon, dangerous) {
    return {
        id: id,
        icon: icon,
        labelKey: "center_notch.action." + id,
        available: false,
        dangerous: dangerous === true,
        intent: "center-notch:" + id
    };
}

function tools() {
    return [
        descriptor("screenshot", "screenshot", false),
        descriptor("screen-recording", "videocam", false),
        descriptor("color-picker", "colorize", false),
        descriptor("ocr", "document_scanner", false),
        descriptor("qr-scan", "qr_code_scanner", false),
        descriptor("camera-mirror", "camera", false),
        descriptor("night-mode", "dark_mode", false),
        descriptor("more-tools", "apps", false)
    ];
}

function session() {
    return [
        descriptor("lock", "lock", false),
        descriptor("logout", "logout", true),
        descriptor("sleep", "bedtime", false),
        descriptor("hibernate", "mode_standby", true),
        descriptor("restart", "restart_alt", true),
        descriptor("shutdown", "power_settings_new", true)
    ];
}
