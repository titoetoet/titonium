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

function parseCpuName(text) {
    if (typeof text !== "string")
        return null;
    const match = text.match(/^model name\s*:\s*(.+)$/m);
    return match && match[1].trim().length > 0 ? match[1].trim() : null;
}

function parseAverageCpuFrequencyGhz(text) {
    if (typeof text !== "string")
        return null;
    const lines = text.split(/\r?\n/);
    let sumMhz = 0;
    let count = 0;
    for (let index = 0; index < lines.length; index++) {
        const match = lines[index].match(/^cpu MHz\s*:\s*(\d+(?:\.\d+)?)$/);
        if (!match)
            continue;
        const mhz = finiteNonNegative(match[1]);
        if (mhz === null)
            continue;
        sumMhz += mhz;
        count++;
    }
    return count > 0 ? sumMhz / count / 1000 : null;
}

function parseGpuClock(text) {
    if (typeof text !== "string")
        return null;
    const lines = text.split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
        const match = lines[index].match(/^\s*\d+:\s*(\d+(?:\.\d+)?)\s*Mhz\s*\*\s*$/i);
        if (match)
            return finiteNonNegative(match[1]);
    }
    return null;
}

function parseGpuName(text) {
    if (typeof text !== "string")
        return null;
    const lines = text.split(/\r?\n/);
    let line = "";
    for (let index = 0; index < lines.length; index++) {
        if (lines[index].trim().length > 0) {
            line = lines[index];
            break;
        }
    }
    if (!line)
        return null;
    const quoted = line.match(/"[^"\r\n]+"/g) || [];
    if (quoted.length < 3)
        return null;
    const fields = quoted.map(value => value.slice(1, -1).trim());
    const candidate = fields.length >= 5 ? fields[fields.length - 1] : fields[2];
    return candidate.length > 0 ? candidate : null;
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

function parseStorageCapacity(text) {
    if (typeof text !== "string")
        return null;
    const lines = text.split(/\r?\n/);
    for (let index = 0; index < lines.length; index++) {
        const match = lines[index].match(/^\s*(\d+)\s+(\d+)\s*$/);
        if (match)
            return capacity(match[2], match[1]);
    }
    return null;
}

function parseProcesses(text) {
    if (typeof text !== "string")
        return Object.freeze([]);
    const grouped = {};
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
        const name = fields[1];
        const key = name.toLowerCase();
        if (!grouped[key]) {
            grouped[key] = {
                pid: pid,
                name: name,
                cpuPercent: 0,
                rssBytes: 0,
                processCount: 0,
            };
        }
        grouped[key].pid = Math.min(grouped[key].pid, pid);
        grouped[key].cpuPercent += cpu;
        grouped[key].rssBytes += rssKb * 1024;
        grouped[key].processCount++;
    }
    const processes = Object.keys(grouped).map(key => Object.freeze(grouped[key]));
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
            /^(\/sys\/class\/drm\/card[^/]+\/device)\/(gpu_busy_percent|mem_info_vram_used|mem_info_vram_total|pp_dpm_sclk)$/);
        if (!match)
            continue;
        if (!groups[match[1]])
            groups[match[1]] = {};
        const key = ({
            gpu_busy_percent: "gpuBusy",
            mem_info_vram_used: "vramUsed",
            mem_info_vram_total: "vramTotal",
            pp_dpm_sclk: "gpuClock",
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
        }
    }
    const cpuNames = candidates.filter(path =>
        path.indexOf("/sys/class/hwmon/hwmon") === 0 && path.endsWith("/name"));
    if (cpuNames.length > 0) {
        const cpuPrefix = cpuNames[0].slice(0, -5);
        const cpuTemperature = cpuPrefix + "/temp1_input";
        if (candidates.indexOf(cpuTemperature) >= 0)
            selected.cpuTemperature = cpuTemperature;
    }
    return Object.freeze(selected);
}
