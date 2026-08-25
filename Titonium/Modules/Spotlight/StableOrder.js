.pragma library

function compare(left, right) {
    const leftText = String(left || "");
    const rightText = String(right || "");
    const leftKey = leftText.toLowerCase();
    const rightKey = rightText.toLowerCase();
    if (leftKey < rightKey)
        return -1;
    if (leftKey > rightKey)
        return 1;
    if (leftText < rightText)
        return -1;
    if (leftText > rightText)
        return 1;
    return 0;
}
