.pragma library

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function artistText(value) {
    if (Array.isArray(value)) {
        return value.map(function(candidate) {
            return text(candidate);
        }).filter(function(candidate) {
            return candidate.length > 0;
        }).join(", ");
    }
    return text(value);
}

function playbackState(value) {
    var normalized = text(value).toLowerCase();
    return normalized === "playing" || normalized === "paused" ? normalized : "stopped";
}

function normalizePlayer(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    var identity = text(raw.identity);
    if (!identity)
        return null;
    var title = text(raw.trackTitle);
    var artist = artistText(raw.trackArtist);
    return Object.freeze({
        identity: identity,
        playbackState: playbackState(raw.playbackState),
        trackTitle: title,
        trackArtist: artist,
        desktopEntry: text(raw.desktopEntry),
        trackArtUrl: text(raw.trackArtUrl),
        trackLength: Number.isFinite(raw.trackLength) && raw.trackLength > 0 ? raw.trackLength : 0,
        trackPosition: Number.isFinite(raw.trackPosition) && raw.trackPosition >= 0 ? raw.trackPosition : 0,
        canTogglePlaying: raw.canTogglePlaying === true,
        canGoPrevious: raw.canGoPrevious === true,
        canGoNext: raw.canGoNext === true,
        title: artist && title ? artist + " · " + title : title,
        changedAt: Number.isFinite(raw.changedAt) && raw.changedAt >= 0 ? raw.changedAt : 0,
    });
}

function stateRank(value) {
    return value === "playing" ? 2 : value === "paused" ? 1 : 0;
}

function select(players) {
    if (!Array.isArray(players))
        return null;
    var candidates = players.map(normalizePlayer).filter(function(candidate) {
        return candidate !== null;
    });
    candidates.sort(function(left, right) {
        var stateDifference = stateRank(right.playbackState) - stateRank(left.playbackState);
        if (stateDifference !== 0)
            return stateDifference;
        if (right.changedAt !== left.changedAt)
            return right.changedAt - left.changedAt;
        return left.identity < right.identity ? -1 : left.identity > right.identity ? 1 : 0;
    });
    return candidates.length > 0 ? candidates[0] : null;
}

function signature(player) {
    var value = normalizePlayer(player);
    if (!value)
        return "";
    return [value.identity, value.playbackState, value.trackArtist, value.trackTitle,
        value.desktopEntry, value.trackArtUrl, value.canTogglePlaying,
        value.canGoPrevious, value.canGoNext, value.trackLength, value.trackPosition].join("\u001f");
}

function activity(player, now) {
    var value = normalizePlayer(player);
    if (!value || value.playbackState !== "playing" || !value.trackTitle)
        return null;
    return Object.freeze({
        id: "media:current",
        source: "media",
        label: value.title,
        icon: "music_note",
        importance: "normal",
        progress: value.trackLength > 0
            ? Math.max(0, Math.min(100, value.trackPosition / value.trackLength * 100))
            : -1,
        deadline: 0,
        updatedAt: Number.isFinite(now) ? now : 0,
        trackLength: value.trackLength,
        trackPosition: value.trackPosition,
    });
}

function indicatorActive(player) {
    var value = normalizePlayer(player);
    return value !== null && value.playbackState === "playing";
}

function trackSignature(player) {
    return [player.identity, player.trackArtist, player.trackTitle].join("\u001f");
}

function event(kind, player, now) {
    return Object.freeze({
        id: "media:current",
        deduplicationKey: "media:current",
        source: "media",
        kind: kind,
        title: player.title,
        icon: "music_note",
        createdAt: Number.isFinite(now) ? now : 0,
    });
}

function transition(previous, selected, now) {
    var before = normalizePlayer(previous);
    var next = normalizePlayer(selected);
    if (!next)
        return Object.freeze({ next: null, event: null });
    if (!before || signature(before) === signature(next))
        return Object.freeze({ next: next, event: null });
    if (next.playbackState === "stopped" || !next.trackTitle)
        return Object.freeze({ next: next, event: null });
    if (trackSignature(before) !== trackSignature(next))
        return Object.freeze({ next: next, event: event("track_changed", next, now) });
    if (before.playbackState === "playing" && next.playbackState === "paused")
        return Object.freeze({ next: next, event: event("paused", next, now) });
    if (before.playbackState !== "playing" && next.playbackState === "playing")
        return Object.freeze({ next: next, event: event("resumed", next, now) });
    return Object.freeze({ next: next, event: null });
}
