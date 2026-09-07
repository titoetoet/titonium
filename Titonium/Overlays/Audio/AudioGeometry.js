.pragma library

function deviceListHeight(count, rowHeight, spacing, cap) {
    var total = Math.max(0, Math.floor(Number(count) || 0));
    if (total === 0)
        return 0;
    var height = Math.max(0, Number(rowHeight) || 0);
    var gap = Math.max(0, Number(spacing) || 0);
    var maximum = Math.max(0, Number(cap) || 0);
    return Math.min(maximum, total * height + (total - 1) * gap);
}

function streamListHeight(count, rowHeight, spacing) {
    const rows = Math.min(3, Math.max(0, Math.floor(Number(count) || 0)));
    return rows === 0 ? 0 : rows * Math.max(0, Number(rowHeight) || 0)
        + (rows - 1) * Math.max(0, Number(spacing) || 0);
}
