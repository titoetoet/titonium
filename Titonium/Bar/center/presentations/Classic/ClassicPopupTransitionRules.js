.pragma library

function initialState() {
    return Object.freeze({ phase: "idle", token: 0, generation: 0,
        presentedMode: "", presentedContextId: "", completionPending: false });
}

function stateValue(values) {
    return Object.freeze({
        phase: values.phase || "idle",
        token: Math.max(0, Number(values.token) || 0),
        generation: Math.max(0, Number(values.generation) || 0),
        presentedMode: String(values.presentedMode || ""),
        presentedContextId: String(values.presentedContextId || ""),
        completionPending: values.completionPending === true,
    });
}

function isPopup(mode) {
    return mode === "banner" || mode === "expanded";
}

function visualValue(value, fallback) {
    var number = Number(value);
    return Number.isFinite(number) ? number : fallback;
}

function transition(state, event) {
    var current = state || initialState();
    var value = event && typeof event === "object" ? event : {};
    if (value.transitionOwner !== true)
        return Object.freeze({ state: current, effects: Object.freeze([]) });
    var mode = String(value.mode || "");
    var nextPopup = isPopup(mode);
    var hadPopup = isPopup(current.presentedMode);
    var token = current.token + 1;
    var generation = Math.max(0, Number(value.generation) || 0);
    var effects = [];
    if (current.phase === "opening" || current.phase === "closing")
        effects.push(Object.freeze({ type: "cancel-animation", token: current.token }));
    if (nextPopup && !hadPopup) {
        var opening = stateValue({ phase: value.reducedMotion === true ? "idle" : "opening",
            token: token, generation: generation, presentedMode: mode,
            presentedContextId: value.contextId, completionPending: true });
        if (value.reducedMotion === true)
            effects.push(Object.freeze({ type: "complete", token: token, generation: generation }));
        else
            effects.push(Object.freeze({ type: "animate", phase: "opening", token: token,
                generation: generation,
                from: Object.freeze({ opacity: 0, scale: 0.94, y: -12 }),
                to: Object.freeze({ opacity: 1, scale: 1, y: 0 }),
                duration: Object.freeze({ opacity: 150, scale: 220, y: 220 }) }));
        return Object.freeze({ state: opening, effects: Object.freeze(effects) });
    }
    if (nextPopup && current.phase === "closing") {
        var reopenVisual = value.visual || {};
        var reopened = stateValue({ phase: value.reducedMotion === true ? "idle" : "opening",
            token: token, generation: generation, presentedMode: mode,
            presentedContextId: value.contextId, completionPending: true });
        if (value.reducedMotion === true)
            effects.push(Object.freeze({ type: "complete", token: token, generation: generation }));
        else
            effects.push(Object.freeze({ type: "animate", phase: "opening", token: token,
                generation: generation,
                from: Object.freeze({ opacity: visualValue(reopenVisual.opacity, 1),
                    scale: visualValue(reopenVisual.scale, 1),
                    y: visualValue(reopenVisual.y, 0) }),
                to: Object.freeze({ opacity: 1, scale: 1, y: 0 }),
                duration: Object.freeze({ opacity: 150, scale: 220, y: 220 }) }));
        return Object.freeze({ state: reopened, effects: Object.freeze(effects) });
    }
    if (nextPopup) {
        var replaced = stateValue({ phase: "idle", token: token, generation: generation,
            presentedMode: mode, presentedContextId: value.contextId,
            completionPending: true });
        effects.push(Object.freeze({ type: "complete", token: token, generation: generation }));
        return Object.freeze({ state: replaced, effects: Object.freeze(effects) });
    }
    if (hadPopup) {
        var visual = value.visual || {};
        var closing = stateValue({ phase: value.reducedMotion === true ? "idle" : "closing",
            token: token, generation: generation, presentedMode: current.presentedMode,
            presentedContextId: current.presentedContextId, completionPending: true });
        var from = Object.freeze({ opacity: visualValue(visual.opacity, 1),
            scale: visualValue(visual.scale, 1), y: visualValue(visual.y, 0) });
        if (value.reducedMotion === true)
            effects.push(Object.freeze({ type: "complete", token: token, generation: generation }));
        else
            effects.push(Object.freeze({ type: "animate", phase: "closing", token: token,
                generation: generation, from: from,
                to: Object.freeze({ opacity: 0, scale: 0.96, y: -8 }),
                duration: Object.freeze({ opacity: 120, scale: 130, y: 130 }) }));
        return Object.freeze({ state: closing, effects: Object.freeze(effects) });
    }
    return Object.freeze({ state: stateValue(Object.assign({}, current,
        { token: token, generation: generation })), effects: Object.freeze(effects) });
}

function complete(state, token) {
    var current = state || initialState();
    if (Number(token) !== current.token || !current.completionPending)
        return Object.freeze({ state: current, effects: Object.freeze([]) });
    return Object.freeze({ state: stateValue(Object.assign({}, current,
        { phase: "idle", completionPending: false })), effects: Object.freeze([
        Object.freeze({ type: "emit-completion", generation: current.generation })
    ]) });
}

function setReducedMotion(state, reduced) {
    var current = state || initialState();
    if (reduced !== true || (current.phase !== "opening" && current.phase !== "closing"))
        return Object.freeze({ state: current, effects: Object.freeze([]) });
    var closing = current.phase === "closing";
    var normalized = stateValue(Object.assign({}, current,
        { phase: "idle", completionPending: false }));
    return Object.freeze({ state: normalized, effects: Object.freeze([
        Object.freeze({ type: "cancel-animation", token: current.token }),
        Object.freeze({ type: "normalize", opacity: closing ? 0 : 1,
            scale: closing ? 0.96 : 1, y: closing ? -8 : 0 }),
        Object.freeze({ type: "emit-completion", generation: current.generation }),
    ]) });
}

function transformedBounds(bounds, scale, translateY) {
    var value = bounds || {};
    var width = Math.max(0, Number(value.width) || 0);
    var height = Math.max(0, Number(value.height) || 0);
    var factor = Math.max(0, Number(scale) || 0);
    var rounded = number => Math.round(number * 1000000) / 1000000;
    return Object.freeze({
        x: rounded((Number(value.x) || 0) + (width - width * factor) / 2),
        y: rounded((Number(value.y) || 0) + (Number(translateY) || 0)),
        width: rounded(width * factor), height: rounded(height * factor),
    });
}

function popupGeometry(size, available, top) {
    var width = Math.min(Math.max(0, Number(size && size.width) || 0),
        Math.max(0, Number(available && available.width) || 0));
    var y = Math.max(0, Number(top) || 0);
    var height = Math.min(Math.max(0, Number(size && size.height) || 0),
        Math.max(0, (Number(available && available.height) || 0) - y));
    return Object.freeze({ x: Math.max(0,
        ((Number(available && available.width) || 0) - width) / 2),
        y: y, width: width, height: height });
}

function bannerLayout(width, height, padding) {
    var inset = Math.max(0, Number(padding) || 0);
    return Object.freeze({ contentWidth: Math.max(0, (Number(width) || 0) - inset * 2),
        contentHeight: Math.max(0, (Number(height) || 0) - inset * 2),
        iconSize: 18, actionHeight: 28, titleLines: 1, subtitleLines: 1 });
}
