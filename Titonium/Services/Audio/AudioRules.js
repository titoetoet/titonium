.pragma library

function finite(value) {
    return typeof value === "number" && Number.isFinite(value);
}

function maximumOutput(allowAmplification) {
    return allowAmplification === true ? 1.5 : 1.0;
}

function clampOutput(value, allowAmplification) {
    if (!finite(value))
        return null;
    return Math.max(0, Math.min(maximumOutput(allowAmplification), value));
}

function clampUnit(value) {
    if (!finite(value))
        return null;
    return Math.max(0, Math.min(1.0, value));
}

function adjustOutput(value, delta, allowAmplification) {
    if (!finite(value) || !finite(delta))
        return null;
    return clampOutput(value + delta, allowAmplification);
}

function volumeIcon(available, muted, volume) {
    if (available !== true || muted === true)
        return "volume_off";
    if (!finite(volume) || volume <= 0.33)
        return "volume_mute";
    return volume <= 0.66 ? "volume_down" : "volume_up";
}

function isPlaybackStream(node) {
    if (!node || node.audio == null || node.isStream !== true)
        return false;
    var mediaClass = properties(node)["media.class"];
    if (typeof mediaClass === "string" && mediaClass.length > 0)
        return mediaClass.indexOf("Stream/Output/") === 0;
    return node.isSink !== true;
}

function properties(node) {
    return node && node.properties && typeof node.properties === "object" ? node.properties : {};
}

function firstText(values, fallback) {
    for (var index = 0; index < values.length; index++) {
        if (typeof values[index] === "string" && values[index].length > 0)
            return values[index];
    }
    return fallback;
}

function streamName(node, fallback) {
    var props = properties(node);
    return firstText([props["application.name"], props["media.name"], props["node.description"],
        props["node.nick"], node && node.description, node && node.nickname],
        typeof fallback === "string" ? fallback : "Audio stream");
}

function streamIcon(node) {
    return firstText([properties(node)["application.icon-name"]], "audio-x-generic");
}

function normalizedStreams(nodes, fallback, pipewireReady) {
    if (pipewireReady !== true)
        return [];
    var source = Array.isArray(nodes) ? nodes : [];
    return source.filter(isPlaybackStream).map(function (node) {
        var audio = node.audio || {};
        var volume = clampUnit(audio.volume);
        return {
            id: node.id,
            name: streamName(node, fallback),
            icon: streamIcon(node),
            volume: volume === null ? 0 : volume,
            muted: audio.muted === true,
            available: node.ready === true,
        };
    }).sort(function (left, right) {
        var names = left.name.toLocaleLowerCase().localeCompare(right.name.toLocaleLowerCase());
        if (names !== 0)
            return names;
        if (typeof left.id === "number" && typeof right.id === "number")
            return left.id - right.id;
        return String(left.id).localeCompare(String(right.id));
    });
}

function isOutputDevice(node) {
    return !!node && node.audio != null && node.isSink === true
        && node.isStream !== true && node.ready === true;
}

function outputDeviceName(node, fallback) {
    return firstText([node && node.description, node && node.nickname, node && node.name],
        typeof fallback === "string" ? fallback : "Output");
}

function outputDeviceIcon(node) {
    var props = properties(node);
    return firstText([props["device.icon-name"], props["media.icon-name"]], "volume_up");
}

function normalizedOutputDevices(nodes, selectedId, fallback) {
    var source = Array.isArray(nodes) ? nodes : [];
    var selected = Number(selectedId);
    return source.filter(isOutputDevice).map(function (node) {
        return Object.freeze({
            id: node.id,
            name: outputDeviceName(node, fallback),
            icon: outputDeviceIcon(node),
            selected: Number(node.id) === selected,
        });
    }).sort(function (left, right) {
        if (left.selected !== right.selected)
            return left.selected ? -1 : 1;
        var names = left.name.toLocaleLowerCase().localeCompare(right.name.toLocaleLowerCase());
        return names !== 0 ? names : Number(left.id) - Number(right.id);
    });
}

function normalizedBluetoothAddress(value) {
    if (typeof value !== "string")
        return "";
    var normalized = value.toLocaleLowerCase().replace(/[^0-9a-f]/g, "");
    return normalized.length === 12 ? normalized : "";
}

function bluetoothSinkFor(nodes, address) {
    var target = normalizedBluetoothAddress(address);
    if (!target)
        return null;
    var source = Array.isArray(nodes) ? nodes : [];
    for (var index = 0; index < source.length; index++) {
        var node = source[index];
        if (!node || node.isSink !== true || node.isStream === true || node.ready !== true)
            continue;
        var props = properties(node);
        var candidates = [props["api.bluez5.address"], props["device.string"],
            props["device.name"], props["node.name"], node.name];
        for (var candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
            var candidate = normalizedBluetoothAddress(candidates[candidateIndex]);
            if (candidate === target)
                return node;
            if (typeof candidates[candidateIndex] === "string") {
                var embedded = candidates[candidateIndex].toLocaleLowerCase()
                    .replace(/[^0-9a-f]/g, "");
                if (embedded.indexOf(target) >= 0)
                    return node;
            }
        }
    }
    return null;
}

function presentationEvent(previous, current) {
    var next = {
        key: current && typeof current.key === "string" ? current.key : "",
        available: !!(current && current.available === true),
        volume: current && finite(current.volume) ? current.volume : 0,
        muted: !!(current && current.muted === true),
    };
    var emit = !!previous && previous.available === true && next.available && next.key.length > 0
        && previous.key === next.key
        && (previous.volume !== next.volume || previous.muted !== next.muted);
    return { emit: emit, next: next };
}

function isCaptureStream(node) {
    var props = node?.properties || {};
    return node?.ready === true && node.isStream === true && !!node.audio
        && props['media.class'] === 'Stream/Input/Audio'
        && String(props['stream.monitor']) !== 'true'
        && String(props['stream.capture.sink']) !== 'true'
        && props['media.category'] !== 'Monitor';
}
function captureSessions(previous, facts, now) {
    return facts.filter(isCaptureStream).map(function(node) {
        var key = String(node.id) + ':' + String(node.properties['object.serial'] || node.id);
        var old = previous.find(function(item) { return item.key === key; });
        return Object.freeze({key: key, nodeId: node.id, startedAt: old ? old.startedAt : now,
            title: node.description || node.name || '', muted: node.audio.muted === true});
    });
}
