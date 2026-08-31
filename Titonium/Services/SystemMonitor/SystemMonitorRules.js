.pragma library

function finiteNonNegative(value) {
    const number = Number(value);
    return Number.isFinite(number) && number >= 0 ? number : null;
}

function parseCpuStat(text) {
    if (typeof text !== "string")
        return null;
    const lines = text.split(/\r?\n/);
    let fields = null;
    for (let index = 0; index < lines.length; index++) {
        const match = lines[index].match(/^cpu\s+(.+)$/);
        if (match) {
            fields = match[1].trim().split(/\s+/);
            break;
        }
    }
    if (!fields || fields.length < 8)
        return null;

    const values = [];
    for (let index = 0; index < 8; index++) {
        const value = finiteNonNegative(fields[index]);
        if (value === null)
            return null;
        values.push(value);
    }
    const total = values.reduce((sum, value) => sum + value, 0);
    const idle = values[3] + values[4];
    return Object.freeze({ total: total, idle: idle });
}

function cpuPercent(previous, current) {
    if (!previous || !current)
        return null;
    const totalDelta = Number(current.total) - Number(previous.total);
    const idleDelta = Number(current.idle) - Number(previous.idle);
    const activeDelta = totalDelta - idleDelta;
    if (!Number.isFinite(totalDelta) || !Number.isFinite(activeDelta)
            || totalDelta <= 0 || activeDelta < 0)
        return null;
    return Math.max(0, Math.min(100, activeDelta / totalDelta * 100));
}

function parseMeminfo(text) {
    if (typeof text !== "string")
        return null;
    const totalMatch = text.match(/^MemTotal:\s+(\d+)\s+kB$/m);
    const availableMatch = text.match(/^MemAvailable:\s+(\d+)\s+kB$/m);
    if (!totalMatch || !availableMatch)
        return null;
    const totalKb = finiteNonNegative(totalMatch[1]);
    const availableKb = finiteNonNegative(availableMatch[1]);
    if (totalKb === null || availableKb === null || totalKb <= 0
            || availableKb > totalKb)
        return null;
    const totalBytes = totalKb * 1024;
    const usedBytes = (totalKb - availableKb) * 1024;
    return Object.freeze({
        totalBytes: totalBytes,
        usedBytes: usedBytes,
        percent: usedBytes / totalBytes * 100,
    });
}

function parseNetDev(text) {
    if (typeof text !== "string")
        return null;
    let rxBytes = 0;
    let txBytes = 0;
    let found = false;
    const lines = text.split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
        const separator = lines[index].indexOf(":");
        if (separator < 0)
            continue;
        const interfaceName = lines[index].slice(0, separator).trim();
        if (!interfaceName || interfaceName === "lo")
            continue;
        const fields = lines[index].slice(separator + 1).trim().split(/\s+/);
        if (fields.length < 16)
            continue;
        const rx = finiteNonNegative(fields[0]);
        const tx = finiteNonNegative(fields[8]);
        if (rx === null || tx === null)
            continue;
        rxBytes += rx;
        txBytes += tx;
        found = true;
    }
    return found ? Object.freeze({ rxBytes: rxBytes, txBytes: txBytes }) : null;
}

function networkRate(previous, current, elapsedMs) {
    if (!previous || !current)
        return null;
    const elapsed = Number(elapsedMs);
    const rxDelta = Number(current.rxBytes) - Number(previous.rxBytes);
    const txDelta = Number(current.txBytes) - Number(previous.txBytes);
    if (!Number.isFinite(elapsed) || elapsed <= 0
            || !Number.isFinite(rxDelta) || !Number.isFinite(txDelta)
            || rxDelta < 0 || txDelta < 0)
        return null;
    const seconds = elapsed / 1000;
    return Object.freeze({
        downBps: rxDelta / seconds,
        upBps: txDelta / seconds,
    });
}
