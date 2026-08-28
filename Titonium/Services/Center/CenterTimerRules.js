.pragma library

var FIVE_MINUTES_MS = 5 * 60 * 1000;
var ONE_MINUTE_MS = 60 * 1000;

function idText(value) {
    return typeof value === "string" ? value.trim() : "";
}

function labelText(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function timestamp(value, fallback) {
    return Number.isFinite(value) ? value : fallback;
}

function frozenArray(values) {
    return Object.freeze(values.slice());
}

function timerValue(id, label, deadline, fiveMinutePending, oneMinutePending) {
    return Object.freeze({
        id: id,
        label: label,
        deadline: deadline,
        fiveMinutePending: fiveMinutePending,
        oneMinutePending: oneMinutePending,
    });
}

function initialState() {
    return frozenArray([]);
}

function ordered(timers) {
    var next = timers.slice();
    next.sort(function(left, right) {
        return left.id < right.id ? -1 : (left.id > right.id ? 1 : 0);
    });
    return frozenArray(next);
}

function start(state, id, durationSeconds, label, now) {
    var timers = Array.isArray(state) ? state : initialState();
    var normalizedId = idText(id);
    var normalizedLabel = labelText(label);
    var seconds = Number(durationSeconds);
    if (!normalizedId || !normalizedLabel || !Number.isFinite(seconds) || seconds <= 0)
        return timers;

    var startedAt = timestamp(now, 0);
    var durationMs = seconds * 1000;
    var deadline = startedAt + durationMs;
    if (!Number.isFinite(deadline))
        return timers;

    var next = timers.filter(function(timer) {
        return timer.id !== normalizedId;
    });
    next.push(timerValue(
        normalizedId,
        normalizedLabel,
        deadline,
        durationMs > FIVE_MINUTES_MS,
        durationMs > ONE_MINUTE_MS
    ));
    return ordered(next);
}

function cancel(state, id) {
    var timers = Array.isArray(state) ? state : initialState();
    var normalizedId = idText(id);
    if (!normalizedId)
        return timers;
    var next = timers.filter(function(timer) {
        return timer.id !== normalizedId;
    });
    return next.length === timers.length ? timers : ordered(next);
}

function eventValue(timer, kind, createdAt) {
    return Object.freeze({
        id: "timer:" + timer.id,
        deduplicationKey: "timer:" + timer.id,
        source: "timer",
        kind: kind,
        label: timer.label,
        icon: "timer",
        createdAt: createdAt,
    });
}

function nextMilestoneAt(timer) {
    if (timer.fiveMinutePending)
        return timer.deadline - FIVE_MINUTES_MS;
    if (timer.oneMinutePending)
        return timer.deadline - ONE_MINUTE_MS;
    return timer.deadline;
}

function nextWake(state, now) {
    var timers = Array.isArray(state) ? state : [];
    if (timers.length === 0)
        return null;
    var nextAt = nextMilestoneAt(timers[0]);
    for (var index = 1; index < timers.length; index++)
        nextAt = Math.min(nextAt, nextMilestoneAt(timers[index]));
    var nowValue = timestamp(now, 0);
    return Object.freeze({
        at: nextAt,
        delay: Math.max(0, nextAt - nowValue),
    });
}

function advance(state, now) {
    var timers = Array.isArray(state) ? state : [];
    var nowValue = timestamp(now, 0);
    var next = [];
    var events = [];

    timers.forEach(function(timer) {
        if (timer.deadline <= nowValue) {
            events.push(eventValue(timer, "timer_finished", timer.deadline));
            return;
        }

        var fiveMinutePending = timer.fiveMinutePending;
        var oneMinutePending = timer.oneMinutePending;
        if (fiveMinutePending && timer.deadline - FIVE_MINUTES_MS <= nowValue) {
            events.push(eventValue(
                timer, "timer_five_minutes", timer.deadline - FIVE_MINUTES_MS));
            fiveMinutePending = false;
        }
        if (oneMinutePending && timer.deadline - ONE_MINUTE_MS <= nowValue) {
            events.push(eventValue(
                timer, "timer_one_minute", timer.deadline - ONE_MINUTE_MS));
            oneMinutePending = false;
        }
        next.push(timerValue(
            timer.id,
            timer.label,
            timer.deadline,
            fiveMinutePending,
            oneMinutePending
        ));
    });

    events.sort(function(left, right) {
        if (left.createdAt !== right.createdAt)
            return left.createdAt - right.createdAt;
        return left.id < right.id ? -1 : (left.id > right.id ? 1 : 0);
    });

    return Object.freeze({
        next: ordered(next),
        events: frozenArray(events),
    });
}
