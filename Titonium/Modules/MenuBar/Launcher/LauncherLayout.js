.pragma library

function columnCount() {
    return 6;
}

function rowCount() {
    return 4;
}

function pageSize() {
    return columnCount() * rowCount();
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
