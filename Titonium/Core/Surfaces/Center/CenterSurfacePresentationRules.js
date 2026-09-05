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
