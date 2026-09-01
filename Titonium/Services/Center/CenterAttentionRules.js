.pragma library

var POLICY = Object.freeze({
    "center:critical": Object.freeze({ priority: 100, ttl: 0, actionable: true }),
    "center:error": Object.freeze({ priority: 70, ttl: 15000, actionable: false }),
    "center:feedback": Object.freeze({ priority: 10, ttl: 3000, actionable: false }),
    "job:job_requires_action": Object.freeze({ priority: 80, ttl: 0, actionable: true }),
    "job:job_failed": Object.freeze({ priority: 70, ttl: 15000, actionable: true }),
    "timer:timer_finished": Object.freeze({ priority: 70, ttl: 15000, actionable: true }),
    "job:job_completed": Object.freeze({ priority: 40, ttl: 7000, actionable: false }),
    "timer:timer_five_minutes": Object.freeze({ priority: 30, ttl: 4000, actionable: false }),
    "timer:timer_one_minute": Object.freeze({ priority: 30, ttl: 8000, actionable: false }),
    "media:track_changed": Object.freeze({ priority: 20, ttl: 8000, actionable: false }),
    "media:resumed": Object.freeze({ priority: 20, ttl: 5000, actionable: false }),
    "media:paused": Object.freeze({ priority: 20, ttl: 4000, actionable: false }),
    "clipboard:copied": Object.freeze({ priority: 25, ttl: 7000, actionable: false }),
    "notification:new": Object.freeze({ priority: 25, ttl: 7000, actionable: false }),
    "capture:recording_started": Object.freeze({ priority: 50, ttl: 8000, actionable: false }),
    "capture:recording_stopped": Object.freeze({ priority: 35, ttl: 7000, actionable: false }),
    "capture:screenshot_saved": Object.freeze({ priority: 45, ttl: 7000, actionable: false }),
    "bluetooth:device_connected": Object.freeze({ priority: 35, ttl: 7000, actionable: false }),
    "bluetooth:device_disconnected": Object.freeze({ priority: 30, ttl: 5000, actionable: false }),
    "audio:output_changed": Object.freeze({ priority: 35, ttl: 6000, actionable: false }),
    "audio:input_changed": Object.freeze({ priority: 35, ttl: 6000, actionable: false }),
    "audio:volume_changed": Object.freeze({ priority: 30, ttl: 3500, actionable: false }),
    "input:method_changed": Object.freeze({ priority: 30, ttl: 4500, actionable: false }),
    "input:caps_changed": Object.freeze({ priority: 25, ttl: 3500, actionable: false }),
    "input:num_changed": Object.freeze({ priority: 25, ttl: 3500, actionable: false }),
    "job:job_started": Object.freeze({ priority: 10, ttl: 3000, actionable: false }),
});

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function timestamp(value, fallback) {
    return Number.isFinite(value) ? value : fallback;
}

function frozenArray(values) {
    return Object.freeze(values.slice());
}

function stateValue(current, pending, generation) {
    return Object.freeze({
        current: current || null,
        pending: frozenArray(pending || []),
        generation: generation,
    });
}

function initialState() {
    return stateValue(null, [], 0);
}

function normalizeEvent(raw, now) {
    if (!raw || typeof raw !== "object")
        return null;
    var id = text(raw.id);
    var source = text(raw.source);
    var kind = text(raw.kind);
    var title = text(raw.title);
    var policy = POLICY[source + ":" + kind];
    if (!id || !source || !kind || !title || !policy)
        return null;

    var priority = policy.priority;
    var importance = source === "job" && raw.importance === "important"
        ? "important" : "normal";
    if (source === "job" && importance === "important")
        priority = Math.min(90, priority + 10);

    var createdAt = timestamp(raw.createdAt, now);
    var descriptor = {
        id: id,
        source: source,
        kind: kind,
        title: title,
        icon: text(raw.icon) || "info",
        priority: priority,
        createdAt: createdAt,
        expiresAt: policy.ttl > 0 ? now + policy.ttl : 0,
        deduplicationKey: text(raw.deduplicationKey) || id,
        actionable: policy.actionable,
    };
    if (source === "job")
        descriptor.importance = importance;
    return Object.freeze(descriptor);
}

function relevant(event, now) {
    return event && (event.expiresAt === 0 || event.expiresAt > now);
}

function pendingWithout(pending, predicate, now) {
    var next = [];
    for (var index = 0; index < pending.length; index++) {
        var candidate = pending[index];
        if (relevant(candidate, now) && !predicate(candidate))
            next.push(candidate);
    }
    return next;
}

function orderedPending(pending, now) {
    var unique = {};
    var next = [];
    for (var index = 0; index < pending.length; index++) {
        var candidate = pending[index];
        if (!candidate.actionable || !relevant(candidate, now))
            continue;
        var key = candidate.deduplicationKey;
        var previous = unique[key];
        if (!previous || candidate.priority > previous.priority
                || (candidate.priority === previous.priority
                    && candidate.createdAt > previous.createdAt))
            unique[key] = candidate;
    }
    var keys = Object.keys(unique);
    for (var keyIndex = 0; keyIndex < keys.length; keyIndex++)
        next.push(unique[keys[keyIndex]]);
    next.sort(function(left, right) {
        if (left.priority !== right.priority)
            return right.priority - left.priority;
        if (left.createdAt !== right.createdAt)
            return right.createdAt - left.createdAt;
        return left.id < right.id ? -1 : (left.id > right.id ? 1 : 0);
    });
    return next.slice(0, 16);
}

function addPending(pending, event, now) {
    if (!event || !event.actionable || !relevant(event, now))
        return orderedPending(pending, now);
    var next = pendingWithout(pending, function(candidate) {
        return candidate.deduplicationKey === event.deduplicationKey;
    }, now);
    next.push(event);
    return orderedPending(next, now);
}

function advance(pending, generation, now) {
    var ordered = orderedPending(pending, now);
    var current = ordered.length > 0 ? ordered[0] : null;
    return stateValue(current, ordered.slice(1), generation + 1);
}

function publish(state, raw, now) {
    var event = normalizeEvent(raw, now);
    if (!event)
        return state;

    var current = state.current;
    var pending = orderedPending(state.pending, now);
    var generation = state.generation;
    if (current && !relevant(current, now)) {
        var expired = advance(pending, generation, now);
        current = expired.current;
        pending = expired.pending;
        generation = expired.generation;
    }

    if (!current)
        return stateValue(event, pending, generation + 1);

    if (current.deduplicationKey === event.deduplicationKey)
        return stateValue(event, pending, generation + 1);

    var wins = event.priority > current.priority
        || (event.priority === current.priority && event.createdAt >= current.createdAt);
    if (wins) {
        pending = addPending(pending, current, now);
        return stateValue(event, pending, generation + 1);
    }

    if (!event.actionable)
        return state;
    pending = addPending(pending, event, now);
    return stateValue(current, pending, generation);
}

function expire(state, id, generation, now) {
    if (!state.current || state.current.id !== id || state.generation !== generation)
        return state;
    if (state.current.expiresAt === 0 || state.current.expiresAt > now)
        return state;
    return advance(state.pending, state.generation, now);
}

function expiryRequest(state, now) {
    if (!state || !state.current || state.current.expiresAt <= 0)
        return null;
    var nowValue = timestamp(now, 0);
    return Object.freeze({
        id: state.current.id,
        generation: state.generation,
        delay: Math.max(0, state.current.expiresAt - nowValue),
    });
}

function removeEvent(state, id, now) {
    var normalizedId = text(id);
    if (!normalizedId)
        return state;
    var pending = pendingWithout(state.pending, function(candidate) {
        return candidate.id === normalizedId;
    }, now);
    if (state.current && state.current.id === normalizedId)
        return advance(pending, state.generation, now);
    if (pending.length === state.pending.length)
        return state;
    return stateValue(state.current, orderedPending(pending, now), state.generation);
}

function acknowledge(state, id, now) {
    return removeEvent(state, id, now);
}

function clear(state, id, now) {
    return removeEvent(state, id, now);
}

function clearSource(state, source, now) {
    var normalizedSource = text(source);
    if (!normalizedSource)
        return state;
    var pending = pendingWithout(state.pending, function(candidate) {
        return candidate.source === normalizedSource;
    }, now);
    if (state.current && state.current.source === normalizedSource)
        return advance(pending, state.generation, now);
    if (pending.length === state.pending.length)
        return state;
    return stateValue(state.current, orderedPending(pending, now), state.generation);
}

function setIndicator(indicators, raw) {
    if (!raw || typeof raw !== "object")
        return indicators;
    var id = text(raw.id);
    if (!id)
        return indicators;
    var next = [];
    var found = false;
    for (var index = 0; index < indicators.length; index++) {
        var candidate = indicators[index];
        if (candidate.id === id) {
            found = true;
            continue;
        }
        next.push(candidate);
    }
    if (raw.active === true) {
        var icon = text(raw.icon);
        var accessibleName = text(raw.accessibleName);
        if (!icon || !accessibleName)
            return indicators;
        next.push(Object.freeze({
            id: id,
            icon: icon,
            accessibleName: accessibleName,
        }));
    } else if (!found) {
        return indicators;
    }
    return frozenArray(next.slice(0, 8));
}
