.pragma library

function initialIndex(scope) {
    return scope === "clipboard" ? -1 : 0;
}

function move(currentIndex, delta, itemCount) {
    if (!Number.isInteger(itemCount) || itemCount <= 0)
        return -1;
    if (!Number.isInteger(currentIndex) || currentIndex < 0)
        return delta < 0 ? itemCount - 1 : 0;
    return (currentIndex + delta + itemCount) % itemCount;
}

function clamp(currentIndex, itemCount) {
    if (!Number.isInteger(itemCount) || itemCount <= 0)
        return -1;
    if (!Number.isInteger(currentIndex) || currentIndex < 0)
        return -1;
    return Math.min(currentIndex, itemCount - 1);
}

function itemAt(items, index) {
    if (!Array.isArray(items) || !Number.isInteger(index) || index < 0 || index >= items.length)
        return null;
    return items[index];
}
