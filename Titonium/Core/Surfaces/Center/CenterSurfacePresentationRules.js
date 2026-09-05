.pragma library

function transitionOwner(viewState, screenName) {
    var state = viewState && typeof viewState === "object" ? viewState : {};
    var screen = String(screenName || "");
    if (!screen)
        return false;
    var ownsOpen = (state.mode === "banner" || state.mode === "expanded")
        && String(state.ownerScreenName || "") === screen;
    var ownsExit = String(state.exitingScreenName || "") === screen;
    return ownsOpen || ownsExit;
}

function compactExitPending(viewState, screenName, lastOwnerScreenName,
        lastOwnerGeneration, completedGeneration) {
    var state = viewState && typeof viewState === "object" ? viewState : {};
    var screen = String(screenName || "");
    var generation = Math.max(0, Number(state.generation) || 0);
    var previousGeneration = Math.max(0, Number(lastOwnerGeneration) || 0);
    return !!screen && state.mode === "compact"
        && String(state.ownerScreenName || "") === screen
        && String(lastOwnerScreenName || "") === screen
        && previousGeneration > 0 && generation > previousGeneration
        && generation !== Math.max(0, Number(completedGeneration) || 0);
}

function windowPlan(profileId, viewState, screenName) {
    var state = viewState && typeof viewState === "object" ? viewState : {};
    var profile = String(profileId || "");
    var screen = String(screenName || "");
    var owns = !!screen && String(state.ownerScreenName || "") === screen;
    var dismissing = !!screen && String(state.exitingScreenName || "") === screen;
    var compact = owns && state.mode === "compact";
    var popup = owns && (state.mode === "banner" || state.mode === "expanded");
    if (profile === "classic") {
        return Object.freeze({
            compactMapped: false,
            overlayMapped: true,
            presentationActive: owns || dismissing,
            popupActive: popup,
            inputMode: popup ? "fullscreen" : (compact ? "compact"
                : (dismissing ? "painted" : "none")),
            focusActive: popup,
        });
    }
    return Object.freeze({
        compactMapped: compact,
        overlayMapped: popup || dismissing,
        presentationActive: compact || popup || dismissing,
        popupActive: popup,
        inputMode: popup ? "fullscreen" : (compact ? "compact"
            : (dismissing ? "painted" : "none")),
        focusActive: popup,
    });
}
