.pragma library

function boundedCount(available, minimum, gap) {
    const safeAvailable = Math.max(0, Number(available) || 0);
    const safeMinimum = Math.max(1, Number(minimum) || 1);
    const safeGap = Math.max(0, Number(gap) || 0);
    return Math.max(1, Math.floor((safeAvailable + safeGap) / (safeMinimum + safeGap)));
}

function columnCount(width, minimumTileWidth, gap) {
    return boundedCount(width, minimumTileWidth, gap);
}

function rowCount(height, minimumTileHeight, gap) {
    return boundedCount(height, minimumTileHeight, gap);
}

function pageSize(width, height, minimumTileWidth, minimumTileHeight, gap) {
    return Math.max(1, columnCount(width, minimumTileWidth, gap)
        * rowCount(height, minimumTileHeight, gap));
}

function pages(items, capacity) {
    const source = Array.isArray(items) ? items : [];
    const safeCapacity = Math.max(1, Math.floor(Number(capacity) || 1));
    const result = [];
    for (let index = 0; index < source.length; index += safeCapacity)
        result.push(source.slice(index, index + safeCapacity));
    return result.length > 0 ? result : [[]];
}

function fillRatio(page, capacity) {
    const safeCapacity = Math.max(1, Math.floor(Number(capacity) || 1));
    return Math.min(1, Math.max(0, (Array.isArray(page) ? page.length : 0) / safeCapacity));
}
