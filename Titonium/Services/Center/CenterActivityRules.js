.pragma library

var MAX_ACTIVITIES = 32;
var MAX_VISIBLE = 3;
var ALLOWED_FIELDS = Object.freeze({
    id: true,
    source: true,
    label: true,
    icon: true,
    importance: true,
    progress: true,
    deadline: true,
    updatedAt: true,
});

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function frozenArray(values) {
    return Object.freeze(values.slice());
}

function stateValue(activities, currentId, showingFocus, generation) {
    return Object.freeze({
        activities: frozenArray(activities || []),
        currentId: currentId || "",
        showingFocus: showingFocus !== false,
        generation: Number.isFinite(generation) ? generation : 0,
    });
}

function initialState() {
    return stateValue([], "", true, 0);
}

function activityRank(activity) {
    if (activity.source === "timer")
        return 30;
    return activity.importance === "important" ? 25 : 20;
}

function ordered(activities) {
    var next = activities.slice();
    next.sort(function(left, right) {
        var rankDifference = activityRank(right) - activityRank(left);
        if (rankDifference !== 0)
            return rankDifference;
        if (left.updatedAt !== right.updatedAt)
            return right.updatedAt - left.updatedAt;
        return left.id < right.id ? -1 : (left.id > right.id ? 1 : 0);
    });
    return next.slice(0, MAX_ACTIVITIES);
}

function hasOnlyAllowedFields(raw) {
    var keys = Object.keys(raw);
    for (var index = 0; index < keys.length; index++) {
        if (!ALLOWED_FIELDS[keys[index]])
            return false;
    }
    return true;
}

function normalize(raw, now) {
    if (!raw || typeof raw !== "object" || !hasOnlyAllowedFields(raw))
        return null;

    var id = text(raw.id);
    var source = text(raw.source);
    var label = text(raw.label);
    var icon = text(raw.icon);
    var importance = text(raw.importance);
    var updatedAt = Number.isFinite(raw.updatedAt) ? raw.updatedAt : now;
    if (!id || !label || !icon || !Number.isFinite(updatedAt))
        return null;
    if (source !== "timer" && source !== "job")
        return null;
    if (id.indexOf(source + ":") !== 0)
        return null;
    if (importance !== "normal" && importance !== "important")
        return null;

    var progress = Number(raw.progress);
    var deadline = Number(raw.deadline);
    if (source === "job") {
        if (!Number.isFinite(progress) || progress < 0 || progress > 100
                || deadline !== 0)
            return null;
    } else {
        if (importance !== "normal" || progress !== -1
                || !Number.isFinite(deadline) || deadline <= now)
            return null;
    }

    return Object.freeze({
        id: id,
        source: source,
        label: label,
        icon: icon,
        importance: importance,
        progress: progress,
        deadline: deadline,
        updatedAt: updatedAt,
    });
}

function indexOf(activities, id) {
    for (var index = 0; index < activities.length; index++) {
        if (activities[index].id === id)
            return index;
    }
    return -1;
}

function sameActivity(left, right) {
    return left && right
        && left.id === right.id
        && left.source === right.source
        && left.label === right.label
        && left.icon === right.icon
        && left.importance === right.importance
        && left.progress === right.progress
        && left.deadline === right.deadline
        && left.updatedAt === right.updatedAt;
}

function current(state) {
    if (!state || state.showingFocus || !state.currentId)
        return null;
    var position = indexOf(state.activities, state.currentId);
    return position >= 0 ? state.activities[position] : null;
}

function visiblePool(state) {
    if (!state || !Array.isArray(state.activities))
        return frozenArray([]);
    return frozenArray(state.activities.slice(0, MAX_VISIBLE));
}

function upsert(state, raw, now) {
    var currentState = state && Array.isArray(state.activities)
        ? state : initialState();
    var activity = normalize(raw, now);
    if (!activity)
        return currentState;

    var existingIndex = indexOf(currentState.activities, activity.id);
    if (existingIndex >= 0
            && sameActivity(currentState.activities[existingIndex], activity))
        return currentState;

    var nextActivities = currentState.activities.slice();
    if (existingIndex >= 0)
        nextActivities[existingIndex] = activity;
    else
        nextActivities.push(activity);
    nextActivities = ordered(nextActivities);

    var currentId = currentState.currentId;
    var showingFocus = currentState.showingFocus;
    var generation = currentState.generation;
    if (!showingFocus) {
        var nextCurrentIndex = indexOf(nextActivities, currentId);
        if (nextCurrentIndex < 0) {
            currentId = "";
            showingFocus = true;
            generation++;
        } else if (activity.id === currentId) {
            generation++;
        }
    }
    return stateValue(nextActivities, currentId, showingFocus, generation);
}

function remove(state, id) {
    var currentState = state && Array.isArray(state.activities)
        ? state : initialState();
    var normalizedId = text(id);
    var position = indexOf(currentState.activities, normalizedId);
    if (!normalizedId || position < 0)
        return currentState;

    var nextActivities = currentState.activities.slice();
    nextActivities.splice(position, 1);
    if (!currentState.showingFocus && currentState.currentId === normalizedId)
        return stateValue(nextActivities, "", true, currentState.generation + 1);
    return stateValue(
        nextActivities,
        currentState.currentId,
        currentState.showingFocus,
        currentState.generation
    );
}

function advance(state) {
    var currentState = state && Array.isArray(state.activities)
        ? state : initialState();
    var pool = visiblePool(currentState);
    if (pool.length === 0) {
        if (currentState.showingFocus)
            return currentState;
        return stateValue(
            currentState.activities, "", true, currentState.generation + 1);
    }

    if (currentState.showingFocus) {
        return stateValue(
            currentState.activities, pool[0].id, false,
            currentState.generation + 1);
    }

    var position = indexOf(pool, currentState.currentId);
    if (position < 0 || position === pool.length - 1) {
        return stateValue(
            currentState.activities, "", true, currentState.generation + 1);
    }
    return stateValue(
        currentState.activities, pool[position + 1].id, false,
        currentState.generation + 1);
}

function remainingMinutes(deadline, now) {
    if (!Number.isFinite(deadline) || !Number.isFinite(now))
        return 0;
    return Math.max(0, Math.ceil((deadline - now) / 60000));
}
