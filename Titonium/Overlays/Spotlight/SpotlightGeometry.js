.pragma library

function panelTop() {
    return 200;
}

function panelHeight(viewportHeight, bottomGap) {
    const available = Math.max(0, viewportHeight - panelTop() - Math.max(0, bottomGap));
    return Math.min(760, available);
}
