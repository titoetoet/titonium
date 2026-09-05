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
