.pragma library

function idText(value) {
    return typeof value === "string" ? value.trim() : "";
}

function messageText(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function timestamp(value) {
    return Number.isFinite(value) ? value : 0;
}

function frozenArray(values) {
    return Object.freeze(values.slice());
}

function jobValue(id, label, importance, status, percent, changedAt) {
    return Object.freeze({
        id: id,
        label: label,
        importance: importance,
        status: status,
        percent: percent,
        changedAt: changedAt,
    });
}

function ordered(jobs) {
    var next = jobs.slice();
    next.sort(function(left, right) {
        return left.id < right.id ? -1 : (left.id > right.id ? 1 : 0);
    });
    return frozenArray(next);
}

function result(next, event, error) {
    return Object.freeze({
        next: next,
        event: event || null,
        error: error || "",
    });
}

function failed(state, error) {
    return result(state, null, "error:" + error);
}

function initialState() {
    return frozenArray([]);
}

function indexOf(state, id) {
    for (var index = 0; index < state.length; index++) {
        if (state[index].id === id)
            return index;
    }
    return -1;
}

function eventValue(job, kind, title, icon, now) {
    return Object.freeze({
        id: "job:" + job.id,
        deduplicationKey: "job:" + job.id,
        source: "job",
        kind: kind,
        title: title,
        icon: icon,
        importance: job.importance,
        createdAt: timestamp(now),
    });
}

function start(state, id, label, importance, now) {
    var jobs = Array.isArray(state) ? state : initialState();
    var normalizedId = idText(id);
    var normalizedLabel = messageText(label);
    if (!normalizedId || !normalizedLabel)
        return failed(jobs, "invalid");
    if (importance !== "normal" && importance !== "important")
        return failed(jobs, "invalid");
    if (indexOf(jobs, normalizedId) >= 0)
        return failed(jobs, "already_exists");

    var job = jobValue(
        normalizedId, normalizedLabel, importance, "running", 0, timestamp(now));
    var next = jobs.slice();
    next.push(job);
    return result(
        ordered(next),
        eventValue(job, "job_started", normalizedLabel, "work", now),
        ""
    );
}

function progress(state, id, percent, label, now) {
    var jobs = Array.isArray(state) ? state : initialState();
    var normalizedId = idText(id);
    var normalizedLabel = messageText(label);
    var percentText = typeof percent === "number"
        ? String(percent) : (typeof percent === "string" ? percent.trim() : "");
    if (!/^(?:\d+(?:\.\d+)?|\.\d+)$/.test(percentText))
        return failed(jobs, "invalid");
    var normalizedPercent = Number(percentText);
    if (!normalizedId || !normalizedLabel || !Number.isFinite(normalizedPercent)
            || normalizedPercent < 0 || normalizedPercent > 100)
        return failed(jobs, "invalid");
    var index = indexOf(jobs, normalizedId);
    if (index < 0)
        return failed(jobs, "not_found");
    var current = jobs[index];
    if (current.status !== "running")
        return failed(jobs, "invalid_transition");

    var next = jobs.slice();
    next[index] = jobValue(
        current.id,
        normalizedLabel,
        current.importance,
        current.status,
        normalizedPercent,
        timestamp(now)
    );
    return result(ordered(next), null, "");
}

function terminal(state, id, summary, kind, icon, now, keepActive) {
    var jobs = Array.isArray(state) ? state : initialState();
    var normalizedId = idText(id);
    var normalizedSummary = messageText(summary);
    if (!normalizedId || !normalizedSummary)
        return failed(jobs, "invalid");
    var index = indexOf(jobs, normalizedId);
    if (index < 0)
        return failed(jobs, "not_found");
    var current = jobs[index];
    if (current.status !== "running")
        return failed(jobs, "invalid_transition");

    var next = jobs.slice();
    var eventJob = current;
    if (keepActive) {
        eventJob = jobValue(
            current.id,
            normalizedSummary,
            current.importance,
            "requires_action",
            current.percent,
            timestamp(now)
        );
        next[index] = eventJob;
    } else {
        next.splice(index, 1);
    }
    return result(
        ordered(next),
        eventValue(eventJob, kind, normalizedSummary, icon, now),
        ""
    );
}

function complete(state, id, summary, now) {
    return terminal(state, id, summary, "job_completed", "check_circle", now, false);
}

function fail(state, id, summary, now) {
    return terminal(state, id, summary, "job_failed", "error", now, false);
}

function requireAction(state, id, summary, now) {
    return terminal(
        state, id, summary, "job_requires_action", "priority_high", now, true);
}

function clear(state, id) {
    var jobs = Array.isArray(state) ? state : initialState();
    var normalizedId = idText(id);
    if (!normalizedId)
        return failed(jobs, "invalid");
    var index = indexOf(jobs, normalizedId);
    if (index < 0)
        return failed(jobs, "not_found");
    var next = jobs.slice();
    next.splice(index, 1);
    return result(ordered(next), null, "");
}
