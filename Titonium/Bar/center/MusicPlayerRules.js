.pragma library

// Natural Music size only; other Center applications keep their own geometry.
function geometry(availableWidth, availableHeight, titleWidth) {
    var usable = Math.max(0, (Number(availableWidth) || 0) - 24);
    var main = Math.max(260, Math.min(300, Number(titleWidth) || 280));
    var width = Math.min(usable, 324 + main);
    var stacked = width < 560;
    var contentHeight = stacked ? 272 : 152;
    return { width: width, height: Math.min(contentHeight,
        Math.max(0, (Number(availableHeight) || 0) - 24)),
        contentHeight: contentHeight, stacked: stacked, radius: 12 };
}

function duration(value) {
    var seconds = Math.max(0, Math.floor(Number(value) || 0));
    if (!Number.isFinite(seconds)) seconds = 0;
    return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
}
