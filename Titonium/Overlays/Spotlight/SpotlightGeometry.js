.pragma library

function panelTop() {
    return 200;
}

function panelWidth(viewportWidth, sideGap) {
    const available = Math.max(0, viewportWidth - Math.max(0, sideGap) * 4);
    return Math.min(860, available);
}

function panelHeight(viewportHeight, bottomGap) {
    const available = Math.max(0, viewportHeight - panelTop() - Math.max(0, bottomGap));
    return Math.min(740, available);
}
