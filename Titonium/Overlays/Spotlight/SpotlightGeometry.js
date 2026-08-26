.pragma library

function panelTop(barHeight) {
    return Math.max(0, barHeight) + 80;
}

function panelHeight(viewportHeight, barHeight, bottomGap) {
    const available = Math.max(0, viewportHeight - panelTop(barHeight) - Math.max(0, bottomGap));
    return Math.min(760, available);
}
