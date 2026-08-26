.pragma library

function finiteNonNegative(value) {
    const number = Number(value);
    return isFinite(number) ? Math.max(0, number) : 0;
}

function centerX(containerWidth, itemWidth) {
    const container = finiteNonNegative(containerWidth);
    const item = finiteNonNegative(itemWidth);
    return Math.max(0, Math.round((container - item) / 2));
}

function optionalVisibility(containerWidth, startWidth, centerWidth, endWidth, gap) {
    const available = finiteNonNegative(containerWidth);
    const required = finiteNonNegative(startWidth) + finiteNonNegative(centerWidth)
        + finiteNonNegative(endWidth) + finiteNonNegative(gap) * 2;
    const fits = required <= available;
    return {
        showActiveWindow: fits,
        showConnectivityDiagnostics: fits
    };
}
