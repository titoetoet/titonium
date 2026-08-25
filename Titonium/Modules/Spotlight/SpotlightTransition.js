.pragma library

function restingPlan() {
    return {
        animated: false,
        duration: 0,
        startOpacity: 1,
        startOffset: 0
    };
}

function plan(previousMode, nextMode, reducedMotion, transitionStyle, configuredDuration) {
    const crossesGridAndResults = (previousMode === "browse" && nextMode === "results")
        || (previousMode === "results" && nextMode === "browse");
    if (!crossesGridAndResults || reducedMotion === true || transitionStyle === "none")
        return restingPlan();
    const numericDuration = Number(configuredDuration);
    const boundedDuration = isFinite(numericDuration)
        ? Math.max(80, Math.min(220, Math.round(numericDuration))) : 220;
    return {
        animated: true,
        duration: boundedDuration,
        startOpacity: 0,
        startOffset: nextMode === "results" ? 8 : -8
    };
}
