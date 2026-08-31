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

function scalar(text, divisor) {
    if (typeof text !== "string")
        return null;
    const normalized = text.trim();
    const scale = Number(divisor);
    if (!/^(?:\d+\.?\d*|\.\d+)$/.test(normalized)
            || !Number.isFinite(scale) || scale <= 0)
        return null;
    const value = Number(normalized);
    return Number.isFinite(value) && value >= 0 ? value / scale : null;
}

function powerFromEnergy(previousUj, currentUj, elapsedMs, maxRangeUj) {
    const previous = finiteNonNegative(previousUj);
    const current = finiteNonNegative(currentUj);
    const elapsed = Number(elapsedMs);
    const maximum = finiteNonNegative(maxRangeUj);
    if (previous === null || current === null || !Number.isFinite(elapsed)
            || elapsed <= 0)
        return null;
    let delta = current - previous;
    if (delta < 0) {
        if (maximum === null || maximum <= previous)
            return null;
        delta = maximum - previous + current;
    }
    return delta / 1000000 / (elapsed / 1000);
}

function capacity(usedBytes, totalBytes) {
    const used = finiteNonNegative(usedBytes);
    const total = finiteNonNegative(totalBytes);
    if (used === null || total === null || total <= 0)
        return null;
    const boundedUsed = Math.min(used, total);
    return Object.freeze({
        usedBytes: boundedUsed,
        totalBytes: total,
        percent: boundedUsed / total * 100,
    });
}

function parseDf(text) {
    if (typeof text !== "string")
        return null;
    const lines = text.trim().split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
        const fields = lines[index].trim().split(/\s+/);
        for (let offset = 0; offset <= 1; offset++) {
            if (fields.length <= offset + 1 || !/^\d+$/.test(fields[offset])
                    || !/^\d+$/.test(fields[offset + 1]))
                continue;
            return capacity(Number(fields[offset + 1]), Number(fields[offset]));
        }
    }
    return null;
}

function parseProcesses(text) {
    if (typeof text !== "string")
        return Object.freeze([]);
    const processes = [];
    const lines = text.split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
        const fields = lines[index].trim().split(/\s+/);
        if (fields.length !== 4)
            continue;
        const pid = Number(fields[0]);
        const cpu = finiteNonNegative(fields[2]);
        const rssKb = finiteNonNegative(fields[3]);
        if (!Number.isInteger(pid) || pid <= 0 || !fields[1]
                || cpu === null || rssKb === null)
            continue;
        processes.push(Object.freeze({
            pid: pid,
            name: fields[1],
            cpuPercent: cpu,
            rssBytes: rssKb * 1024,
        }));
    }
    processes.sort((left, right) => {
        if (left.cpuPercent !== right.cpuPercent)
            return right.cpuPercent - left.cpuPercent;
        return left.pid - right.pid;
    });
    return Object.freeze(processes.slice(0, 5));
}

function severity(percent, temperatureC) {
    const utilization = finiteNonNegative(percent);
    const temperature = finiteNonNegative(temperatureC);
    if ((utilization !== null && utilization >= 90)
            || (temperature !== null && temperature >= 90))
        return "critical";
    if ((utilization !== null && utilization >= 70)
            || (temperature !== null && temperature >= 80))
        return "warning";
    return "neutral";
}

function selectSensorPaths(paths) {
    const candidates = Array.isArray(paths)
        ? paths.filter(path => typeof path === "string"
            && path.indexOf("/sys/") === 0).sort() : [];
    const groups = {};
    for (let index = 0; index < candidates.length; index++) {
        const match = candidates[index].match(
            /^(\/sys\/class\/drm\/card[^/]+\/device)\/(gpu_busy_percent|mem_info_vram_used|mem_info_vram_total)$/);
        if (!match)
            continue;
        if (!groups[match[1]])
            groups[match[1]] = {};
        const key = ({
            gpu_busy_percent: "gpuBusy",
            mem_info_vram_used: "vramUsed",
            mem_info_vram_total: "vramTotal",
        })[match[2]];
        groups[match[1]][key] = candidates[index];
    }
    const prefixes = Object.keys(groups).sort();
    let selected = {};
    let selectedPrefix = "";
    for (let index = 0; index < prefixes.length; index++) {
        const group = groups[prefixes[index]];
        if (group.gpuBusy && group.vramUsed && group.vramTotal) {
            selected = Object.assign({}, group);
            selectedPrefix = prefixes[index];
            break;
        }
    }
    if (selectedPrefix) {
        for (let index = 0; index < candidates.length; index++) {
            const path = candidates[index];
            if (path.indexOf(selectedPrefix + "/hwmon/") !== 0)
                continue;
            if (!selected.gpuTemperature && path.endsWith("/temp1_input"))
                selected.gpuTemperature = path;
            else if (!selected.gpuPower && path.endsWith("/power1_average"))
                selected.gpuPower = path;
        }
    }
    const cpuNames = candidates.filter(path =>
        path.indexOf("/sys/class/hwmon/hwmon") === 0 && path.endsWith("/name"));
    if (cpuNames.length > 0) {
        const cpuPrefix = cpuNames[0].slice(0, -5);
        const cpuTemperature = cpuPrefix + "/temp1_input";
        const cpuPower = cpuPrefix + "/power1_average";
        if (candidates.indexOf(cpuTemperature) >= 0)
            selected.cpuTemperature = cpuTemperature;
        if (candidates.indexOf(cpuPower) >= 0)
            selected.cpuPower = cpuPower;
    }
    return Object.freeze(selected);
}
