.pragma library

function stateValue(values) {
    return Object.freeze({
        ownerScreenName: values.ownerScreenName || "",
        exitingScreenName: values.exitingScreenName || "",
        mode: values.mode || "closed",
        selectedContextId: values.selectedContextId || "",
        presentationOwner: typeof values.presentationOwner === "string"
            ? values.presentationOwner.trim() : "",
        acquisitionPolicy: values.acquisitionPolicy === "non-preemptive"
            ? "non-preemptive" : "preemptive",
        destination: values.destination || "overview",
        dragProgress: Math.max(0, Math.min(1, Number(values.dragProgress) || 0)),
        focusPolicy: values.focusPolicy === "exclusive" ? "exclusive" : "none",
        dismissalPolicy: ["outside", "timed"].indexOf(values.dismissalPolicy) >= 0
            ? values.dismissalPolicy : "none",
        deadline: Math.max(0, Number(values.deadline) || 0),
        deadlineToken: Math.max(0, Number(values.deadlineToken) || 0),
        remainingMs: Math.max(0, Number(values.remainingMs) || 0),
        generation: Math.max(0, Number(values.generation) || 0)
    });
}

function initialState() {
    return stateValue({});
}

function contextById(snapshot, id) {
    var contexts = snapshot && Array.isArray(snapshot.contexts) ? snapshot.contexts : [];
    for (var index = 0; index < contexts.length; index++) {
        if (contexts[index].id === id)
            return contexts[index];
    }
    return null;
}

function fallbackId(snapshot) {
    if (snapshot && snapshot.primary && contextById(snapshot, snapshot.primary.id))
        return snapshot.primary.id;
    if (snapshot && snapshot.secondary && contextById(snapshot, snapshot.secondary.id))
        return snapshot.secondary.id;
    return "";
}

function nextState(current, changes, incrementGeneration) {
    var values = Object.assign({}, current, changes || {});
    if (incrementGeneration)
        values.generation = current.generation + 1;
    var candidate = stateValue(values);
    return JSON.stringify(candidate) === JSON.stringify(current) ? current : candidate;
}

function automaticPresentationEligible(state, snapshot) {
    if (!state || !state.ownerScreenName)
        return false;
    if (state.mode === "compact")
        return !!(contextById(snapshot, snapshot && snapshot.primary && snapshot.primary.id)
            || contextById(snapshot, snapshot && snapshot.secondary && snapshot.secondary.id));
    return state.mode === "banner" && state.acquisitionPolicy === "non-preemptive";
}

function applyPresentationResult(state, snapshot, result, now) {
    if (!result || result.accepted !== true)
        return state;
    if (result.closePolicy === "compact")
        return transition(state, snapshot, { type: "request-mode", mode: "compact" }, now);
    if (result.closePolicy === "dismiss")
        return transition(state, snapshot, { type: "dismiss" }, now);
    return state;
}

function transition(state, snapshot, intent, now) {
    var current = state && typeof state === "object" ? state : initialState();
    if (!intent || typeof intent !== "object")
        return current;
    var type = String(intent.type || "");
    if (type === "surface-granted") {
        var screenName = String(intent.screenName || "").trim();
        if (!screenName)
            return current;
        return nextState(current, {
            ownerScreenName: screenName, exitingScreenName: "", mode: "compact",
            selectedContextId: current.selectedContextId || fallbackId(snapshot),
            presentationOwner: "",
            acquisitionPolicy: "preemptive", focusPolicy: "none",
            dismissalPolicy: "none", deadline: 0, deadlineToken: 0, remainingMs: 0
        }, current.ownerScreenName !== screenName || current.mode === "closed");
    }
    if (type === "surface-denied")
        return current;
    if (type === "finish-close") {
        if (Number(intent.generation) !== current.generation
                || String(intent.screenName || "") !== current.exitingScreenName)
            return current;
        return nextState(current, { exitingScreenName: "" }, false);
    }
    if (type === "surface-revoked" || type === "dismiss") {
        if (current.mode === "closed")
            return current;
        return nextState(current, {
            exitingScreenName: current.ownerScreenName, ownerScreenName: "", mode: "closed",
            presentationOwner: "",
            acquisitionPolicy: "preemptive", focusPolicy: "none",
            dismissalPolicy: "none", deadline: 0, deadlineToken: 0,
            remainingMs: 0, dragProgress: 0
        }, true);
    }
    if (type === "present") {
        var context = contextById(snapshot, String(intent.contextId || ""));
        if (!context || current.mode === "closed" || current.mode === "expanded"
                || intent.requestedMode !== "banner")
            return current;
        var presentationOwner = String(intent.presentationOwner || "").trim();
        if (current.mode === "banner" && current.presentationOwner
                && current.presentationOwner !== presentationOwner)
            return current;
        var timeout = Math.max(0, Number(intent.timeoutMs) || 0);
        var exclusive = intent.focusPolicy === "exclusive" || context.attention === "blocking";
        return nextState(current, {
            mode: "banner", selectedContextId: context.id,
            presentationOwner: presentationOwner,
            acquisitionPolicy: intent.acquisitionPolicy,
            focusPolicy: exclusive ? "exclusive" : "none",
            dismissalPolicy: timeout > 0 ? "timed" : "outside",
            deadline: timeout > 0 ? Number(now) + timeout : 0,
            deadlineToken: timeout > 0 ? Number(now) + timeout : 0,
            remainingMs: 0, dragProgress: 0
        }, current.mode !== "banner" || current.selectedContextId !== context.id);
    }
    if (type === "request-mode") {
        var mode = String(intent.mode || "");
        if (["compact", "banner", "expanded"].indexOf(mode) < 0 || current.mode === "closed")
            return current;
        return nextState(current, {
            mode: mode,
            presentationOwner: mode === "compact" ? ""
                : (mode === "expanded" ? "user" : current.presentationOwner),
            acquisitionPolicy: mode === "banner"
                ? current.acquisitionPolicy : "preemptive",
            focusPolicy: mode === "expanded" ? "exclusive" : "none",
            dismissalPolicy: mode === "compact" ? "none" : current.dismissalPolicy,
            deadline: mode === "compact" || mode === "expanded" ? 0 : current.deadline,
            deadlineToken: mode === "compact" || mode === "expanded"
                ? 0 : current.deadlineToken,
            remainingMs: mode === "compact" || mode === "expanded" ? 0 : current.remainingMs,
            dragProgress: 0
        }, mode !== current.mode);
    }
    if (type === "activate-context") {
        var selected = contextById(snapshot, String(intent.contextId || ""));
        return selected ? nextState(current, { selectedContextId: selected.id }, false) : current;
    }
    if (type === "snapshot-changed") {
        if (!current.selectedContextId || contextById(snapshot, current.selectedContextId))
            return current;
        return nextState(current, { selectedContextId: fallbackId(snapshot) }, false);
    }
    if (type === "drag-update")
        return nextState(current, { dragProgress: intent.progress }, false);
    if (type === "drag-end") {
        var plan = dragSettlePlan(current.dragProgress, intent.offset, intent.velocity);
        return nextState(current, { dragProgress: plan.targetProgress,
            mode: plan.targetState, focusPolicy: plan.targetState === "expanded"
                ? "exclusive" : current.focusPolicy,
            presentationOwner: plan.targetState === "expanded"
                ? "user" : current.presentationOwner,
            acquisitionPolicy: plan.targetState === "expanded"
                ? "preemptive" : current.acquisitionPolicy,
            dismissalPolicy: plan.targetState === "expanded"
                ? "outside" : current.dismissalPolicy,
            deadline: plan.targetState === "expanded" ? 0 : current.deadline,
            deadlineToken: plan.targetState === "expanded" ? 0 : current.deadlineToken,
            remainingMs: plan.targetState === "expanded" ? 0 : current.remainingMs,
        }, plan.targetState !== current.mode);
    }
    if (type === "timeout") {
        if (!deadlineMatches(current, intent, now))
            return current;
        return nextState(current, { mode: "compact", focusPolicy: "none",
            presentationOwner: "",
            acquisitionPolicy: "preemptive", dismissalPolicy: "none",
            deadline: 0, deadlineToken: 0, remainingMs: 0 }, true);
    }
    if (type === "transition-finished")
        return Number(intent.generation) === current.generation ? current : current;
    return current;
}

function deadlineIdentityMatches(state, intent) {
    return !!state && !!intent
        && Number(intent.generation) === state.generation
        && String(intent.contextId || "") === state.selectedContextId
        && Number(intent.deadline) > 0
        && Number(intent.deadline) === state.deadlineToken;
}

function timedPresentationMatches(state, intent) {
    return deadlineIdentityMatches(state, intent)
        && state.mode === "banner"
        && state.dismissalPolicy === "timed";
}

function deadlineMatches(state, intent, now) {
    return deadlineIdentityMatches(state, intent)
        && state.mode === "banner"
        && state.deadline > 0
        && state.deadline === state.deadlineToken
        && Number.isFinite(now)
        && Number(now) >= state.deadline;
}

function pauseDeadline(state, intent, now) {
    if (!deadlineIdentityMatches(state, intent) || state.mode !== "banner"
            || state.deadline <= 0 || !Number.isFinite(now)
            || Number(now) >= state.deadline)
        return state;
    return nextState(state, { remainingMs: Math.max(0, state.deadline - Number(now)),
        deadline: 0 }, false);
}

function resumeDeadline(state, intent, now) {
    if (!deadlineIdentityMatches(state, intent) || state.mode !== "banner"
            || state.deadline > 0 || state.remainingMs <= 0)
        return state;
    var nextDeadline = Number(now) + state.remainingMs;
    return nextState(state, { deadline: nextDeadline, deadlineToken: nextDeadline,
        remainingMs: 0 }, false);
}

function dragSettlePlan(progress, offset, velocity) {
    var current = Math.max(0, Math.min(1, Number(progress) || 0));
    var expanded = Math.max(0, Number(offset) || 0) >= 48
        || Math.max(0, Number(velocity) || 0) >= 500;
    var targetProgress = expanded ? 1 : 0;
    return Object.freeze({
        targetState: expanded ? "expanded" : "banner",
        targetProgress: targetProgress,
        duration: Math.round(90 + Math.abs(targetProgress - current) * 90)
    });
}
