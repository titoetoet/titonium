.pragma library

// Provisional first-pass bounds in logical pixels; content decides width within them.
function widthFor(monitorWidth, height, contentWidth, satellite, idle) {
    var available = Math.max(0, Number(monitorWidth) || 0);
    var usable = Math.max(0, available - Math.min(32, available * 0.1));
    var h = Math.max(1, Number(height) || 36);
    if (idle) return Math.min(usable, h * 2.4);
    var minimum = Math.min(usable, Math.max(h * 3, available * 0.075));
    var maximum = Math.min(usable, Math.max(minimum, available * 0.25));
    var natural = Math.max(0, Number(contentWidth) || 0) + h * 0.8 + (satellite ? h : 0);
    return Math.round(Math.max(minimum, Math.min(maximum, natural)));
}
function duration(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0));
    var minutes = Math.floor(total / 60);
    return String(minutes).padStart(2, "0") + ":" + String(total % 60).padStart(2, "0");
}
