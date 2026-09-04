.pragma library

var READABLE_MS = 4000;
var HISTORY_LIMIT = 100;
var TOAST_LIMIT = 3;
var CRITICAL_LIMIT = 16;

function keyText(value) {
    return typeof value === "string" ? value.trim() : "";
}

function frozen(values) {
    return Object.freeze(values.slice());
}

function stateValue(history, unreadKeys, toastKeys, criticalQueue,
        currentCritical, deadlineAt, remainingMs, paused, presentationEligible) {
    return Object.freeze({
        history: frozen(history),
        unreadKeys: frozen(unreadKeys),
        toastKeys: frozen(toastKeys),
        criticalQueue: frozen(criticalQueue),
        currentCritical: currentCritical || null,
        deadlineAt: Number.isFinite(deadlineAt) ? Math.max(0, deadlineAt) : 0,
        remainingMs: Number.isFinite(remainingMs) ? Math.max(0, remainingMs) : 0,
        paused: paused === true,
        presentationEligible: presentationEligible !== false,
    });
}

function initialState() {
    return stateValue([], [], [], [], null, 0, 0, false, true);
}

function sourceState(value) {
    return value && typeof value === "object" ? value : initialState();
}

function indexForKey(values, key) {
    for (var index = 0; index < values.length; index++) {
        var candidate = typeof values[index] === "object"
            ? values[index].key : values[index];
        if (keyText(candidate) === key)
            return index;
    }
    return -1;
}

function removeKey(values, key) {
    return values.filter(function(value) {
        var candidate = typeof value === "object" ? value.key : value;
        return keyText(candidate) !== key;
    });
}

function addNewest(keys, key, limit) {
    var result = [key].concat(removeKey(keys, key));
    return result.slice(0, limit);
}

function keySet(values) {
    var result = {};
    values.forEach(function(value) {
        var key = keyText(typeof value === "object" ? value.key : value);
        if (key)
            result[key] = true;
    });
    return result;
}

function boundedPreserving(values, limit, protectedSet) {
    var keep = {};
    var protectedCount = 0;
    values.forEach(function(value) {
        var key = keyText(typeof value === "object" ? value.key : value);
        if (key && protectedSet[key] && !keep[key]) {
            keep[key] = true;
            protectedCount += 1;
        }
    });
    var remaining = Math.max(0, limit - protectedCount);
    values.forEach(function(value) {
        var key = keyText(typeof value === "object" ? value.key : value);
        if (key && !keep[key] && remaining > 0) {
            keep[key] = true;
            remaining -= 1;
        }
    });
    return values.filter(function(value) {
        var key = keyText(typeof value === "object" ? value.key : value);
        return keep[key] === true;
    });
}

function ensureDescriptors(values, descriptors) {
    var result = values.slice();
    descriptors.forEach(function(descriptor) {
        if (indexForKey(result, keyText(descriptor.key)) < 0)
            result.push(descriptor);
    });
    return result;
}

function ensureKeys(values, descriptors) {
    var result = values.slice();
    descriptors.forEach(function(descriptor) {
        var key = keyText(descriptor.key);
        if (indexForKey(result, key) < 0)
            result.push(key);
    });
    return result;
}

function descriptorValid(descriptor) {
    return descriptor && typeof descriptor === "object"
        && keyText(descriptor.key).length > 0
        && ["block", "history", "toast", "center"].indexOf(descriptor.route) >= 0;
}

function presentation(state, queue, now, eligible, retainedKey) {
    var current = null;
    var deadlineAt = 0;
    var remainingMs = 0;
    var paused = false;
    if (retainedKey) {
        var retainedIndex = indexForKey(queue, retainedKey);
        if (retainedIndex >= 0) {
            current = queue[retainedIndex];
            deadlineAt = state.deadlineAt;
            remainingMs = state.remainingMs;
            paused = state.paused;
        }
    }
    if (!current && eligible && queue.length > 0) {
        current = queue[0];
        deadlineAt = now + READABLE_MS;
        remainingMs = READABLE_MS;
    }
    return {
        current: current,
        deadlineAt: deadlineAt,
        remainingMs: remainingMs,
        paused: paused,
    };
}

function publish(value, descriptor, now, eligible, toastsEnabled) {
    var state = sourceState(value);
    if (!descriptorValid(descriptor))
        return state;
    var key = keyText(descriptor.key);
    var nowValue = Number.isFinite(now) ? now : 0;
    var presentationEligible = eligible !== false;
    if (descriptor.route === "block")
        return dismiss(state, key, nowValue);

    var queue = (state.criticalQueue || []).slice();
    var oldIndex = indexForKey(queue, key);
    queue = removeKey(queue, key);
    if (descriptor.route === "center") {
        if (oldIndex >= 0)
            queue.splice(Math.min(oldIndex, queue.length), 0, descriptor);
        else if (queue.length < CRITICAL_LIMIT)
            queue.push(descriptor);
    }
    queue = queue.slice(0, CRITICAL_LIMIT);

    var protectedHistory = keySet(queue);
    var historyCandidates = [descriptor].concat(removeKey(state.history || [], key));
    historyCandidates = ensureDescriptors(historyCandidates, queue);
    var history = boundedPreserving(
        historyCandidates, HISTORY_LIMIT, protectedHistory);

    var unreadCandidates = addNewest(
        state.unreadKeys || [], key, Number.MAX_SAFE_INTEGER);
    var unreadQueue = queue.filter(function(queued) {
        return indexForKey(unreadCandidates, keyText(queued.key)) >= 0;
    });
    unreadCandidates = ensureKeys(unreadCandidates, unreadQueue)
        .filter(function(unreadKey) { return indexForKey(history, unreadKey) >= 0; });
    var unreadKeys = boundedPreserving(
        unreadCandidates, HISTORY_LIMIT, keySet(unreadQueue));

    var toastKeys = removeKey(state.toastKeys || [], key);
    if (descriptor.route === "toast" && toastsEnabled === true)
        toastKeys = addNewest(toastKeys, key, TOAST_LIMIT);

    var retainedKey = state.currentCritical ? keyText(state.currentCritical.key) : "";
    var visible = presentation(state, queue, nowValue, presentationEligible, retainedKey);
    return stateValue(history, unreadKeys, toastKeys, queue, visible.current,
        visible.deadlineAt, visible.remainingMs, visible.paused, presentationEligible);
}

function setPresentationEligible(value, eligible, now) {
    var state = sourceState(value);
    var nextEligible = eligible === true;
    if (state.presentationEligible === nextEligible
            && (state.currentCritical || !nextEligible || state.criticalQueue.length === 0))
        return state;
    var retainedKey = state.currentCritical ? keyText(state.currentCritical.key) : "";
    var visible = presentation(state, state.criticalQueue, Number.isFinite(now) ? now : 0,
        nextEligible, retainedKey);
    return stateValue(state.history, state.unreadKeys, state.toastKeys,
        state.criticalQueue, visible.current, visible.deadlineAt, visible.remainingMs,
        visible.paused, nextEligible);
}

function pause(value, now) {
    var state = sourceState(value);
    if (!state.currentCritical || state.paused)
        return state;
    var nowValue = Number.isFinite(now) ? now : 0;
    var remaining = Math.max(0, state.deadlineAt - nowValue);
    return stateValue(state.history, state.unreadKeys, state.toastKeys,
        state.criticalQueue, state.currentCritical, 0, remaining, true,
        state.presentationEligible);
}

function resume(value, now) {
    var state = sourceState(value);
    if (!state.currentCritical || !state.paused)
        return state;
    var nowValue = Number.isFinite(now) ? now : 0;
    return stateValue(state.history, state.unreadKeys, state.toastKeys,
        state.criticalQueue, state.currentCritical, nowValue + state.remainingMs,
        state.remainingMs, false, state.presentationEligible);
}

function complete(value, key, now, keepUnread) {
    var state = sourceState(value);
    var targetKey = keyText(key);
    if (!state.currentCritical || targetKey !== keyText(state.currentCritical.key))
        return state;
    var queue = removeKey(state.criticalQueue, targetKey);
    var unreadKeys = keepUnread === false
        ? removeKey(state.unreadKeys, targetKey) : state.unreadKeys;
    var visible = presentation(stateValue(state.history, unreadKeys, state.toastKeys,
        queue, null, 0, 0, false, state.presentationEligible), queue,
        Number.isFinite(now) ? now : 0, state.presentationEligible, "");
    return stateValue(state.history, unreadKeys, state.toastKeys, queue,
        visible.current, visible.deadlineAt, visible.remainingMs, visible.paused,
        state.presentationEligible);
}

function read(value, key) {
    var state = sourceState(value);
    var targetKey = keyText(key);
    var unreadKeys = targetKey ? removeKey(state.unreadKeys, targetKey) : [];
    if (unreadKeys.length === state.unreadKeys.length)
        return state;
    return stateValue(state.history, unreadKeys, state.toastKeys,
        state.criticalQueue, state.currentCritical, state.deadlineAt,
        state.remainingMs, state.paused, state.presentationEligible);
}

function dismiss(value, key, now) {
    var state = sourceState(value);
    var targetKey = keyText(key);
    if (!targetKey)
        return state;
    var wasCurrent = state.currentCritical
        && keyText(state.currentCritical.key) === targetKey;
    var history = removeKey(state.history, targetKey);
    var unreadKeys = removeKey(state.unreadKeys, targetKey);
    var toastKeys = removeKey(state.toastKeys, targetKey);
    var queue = removeKey(state.criticalQueue, targetKey);
    if (history.length === state.history.length && queue.length === state.criticalQueue.length
            && toastKeys.length === state.toastKeys.length
            && unreadKeys.length === state.unreadKeys.length)
        return state;
    var retainedKey = wasCurrent || !state.currentCritical
        ? "" : keyText(state.currentCritical.key);
    var visible = presentation(state, queue, Number.isFinite(now) ? now : 0,
        state.presentationEligible, retainedKey);
    return stateValue(history, unreadKeys, toastKeys, queue, visible.current,
        visible.deadlineAt, visible.remainingMs, visible.paused,
        state.presentationEligible);
}

function retireDescriptor(descriptor) {
    var result = {};
    for (var name in descriptor)
        result[name] = descriptor[name];
    result.actions = Object.freeze([]);
    return Object.freeze(result);
}

function retire(value, key, reason, now) {
    var state = sourceState(value);
    var targetKey = keyText(key);
    if (!targetKey)
        return state;
    if (reason === "dismissed")
        return dismiss(state, targetKey, now);
    var wasCurrent = state.currentCritical
        && keyText(state.currentCritical.key) === targetKey;
    var historyChanged = false;
    var history = state.history.map(function(descriptor) {
        if (keyText(descriptor.key) !== targetKey
                || !descriptor.actions || descriptor.actions.length === 0)
            return descriptor;
        historyChanged = true;
        return retireDescriptor(descriptor);
    });
    var toastKeys = removeKey(state.toastKeys, targetKey);
    var queue = removeKey(state.criticalQueue, targetKey);
    if (!historyChanged && !wasCurrent && toastKeys.length === state.toastKeys.length
            && queue.length === state.criticalQueue.length)
        return state;
    var retainedKey = wasCurrent || !state.currentCritical
        ? "" : keyText(state.currentCritical.key);
    var visible = presentation(state, queue, Number.isFinite(now) ? now : 0,
        state.presentationEligible, retainedKey);
    return stateValue(history, state.unreadKeys, toastKeys, queue,
        visible.current, visible.deadlineAt, visible.remainingMs, visible.paused,
        state.presentationEligible);
}

function receivedAt(value) {
    return Number.isFinite(value && value.receivedAt) ? value.receivedAt : 0;
}

function reclassify(value, preferences, now, resolver, toastsEnabled) {
    var state = sourceState(value);
    if (typeof resolver !== "function")
        return state;
    var currentKey = state.currentCritical ? keyText(state.currentCritical.key) : "";
    var queuedKeys = keySet(state.criticalQueue || []);
    var pendingToastKeys = keySet(state.toastKeys || []);
    var pendingKeys = {};
    (state.toastKeys || []).forEach(function(key) { pendingKeys[keyText(key)] = true; });
    (state.criticalQueue || []).forEach(function(descriptor) {
        var key = keyText(descriptor.key);
        if (key !== currentKey)
            pendingKeys[key] = true;
    });

    var mappedByKey = {};
    var history = [];
    (state.history || []).forEach(function(descriptor) {
        var key = keyText(descriptor.key);
        var mapped = descriptor;
        if (key !== currentKey && pendingKeys[key])
            mapped = resolver(descriptor, preferences);
        if (descriptorValid(mapped) && mapped.route !== "block") {
            mappedByKey[key] = mapped;
            history.push(mapped);
        }
    });
    history = history.slice(0, HISTORY_LIMIT);

    var unreadKeys = (state.unreadKeys || []).filter(function(key) {
        return indexForKey(history, keyText(key)) >= 0;
    }).slice(0, HISTORY_LIMIT);
    var queue = [];
    if (currentKey && mappedByKey[currentKey])
        queue.push(state.currentCritical);
    (state.criticalQueue || []).forEach(function(descriptor) {
        var key = keyText(descriptor.key);
        var mapped = mappedByKey[key];
        if (key !== currentKey && mapped && mapped.route === "center"
                && queue.length < CRITICAL_LIMIT)
            queue.push(mapped);
    });
    var promotedCritical = history.filter(function(descriptor) {
        var key = keyText(descriptor.key);
        return key !== currentKey && pendingToastKeys[key] && !queuedKeys[key]
            && descriptor.route === "center";
    });
    promotedCritical.sort(function(left, right) {
        if (receivedAt(left) !== receivedAt(right))
            return receivedAt(left) - receivedAt(right);
        var leftKey = keyText(left.key);
        var rightKey = keyText(right.key);
        return leftKey === rightKey ? 0 : (leftKey < rightKey ? -1 : 1);
    });
    promotedCritical.forEach(function(descriptor) {
        if (queue.length < CRITICAL_LIMIT)
            queue.push(descriptor);
    });
    var toastKeys = [];
    if (toastsEnabled === true) {
        history.forEach(function(descriptor) {
            var key = keyText(descriptor.key);
            if (toastKeys.length < TOAST_LIMIT && key !== currentKey
                    && pendingKeys[key] && descriptor.route === "toast")
                toastKeys.push(key);
        });
    }
    var retainedKey = state.currentCritical ? currentKey : "";
    var visible = presentation(state, queue, Number.isFinite(now) ? now : 0,
        state.presentationEligible, retainedKey);
    return stateValue(history, unreadKeys, toastKeys, queue,
        visible.current, visible.deadlineAt, visible.remainingMs, visible.paused,
        state.presentationEligible);
}

function deadlineMatches(state, scheduledKey, scheduledGeneration,
        activeGeneration, scheduledDeadline, now) {
    var source = sourceState(state);
    return !!source.currentCritical
        && source.paused !== true
        && keyText(scheduledKey) === keyText(source.currentCritical.key)
        && Number.isInteger(scheduledGeneration)
        && scheduledGeneration === activeGeneration
        && Number.isFinite(scheduledDeadline)
        && scheduledDeadline > 0
        && scheduledDeadline === source.deadlineAt
        && Number.isFinite(now)
        && now >= scheduledDeadline;
}
