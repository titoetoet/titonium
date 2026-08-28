.pragma library
// Protected Spotlight vertical slice.

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
        ? Math.max(0, Math.min(500, Math.round(numericDuration))) : 220;
    if (boundedDuration === 0)
        return restingPlan();
    return {
        animated: true,
        duration: boundedDuration,
        startOpacity: 0,
        startOffset: transitionStyle === "fade" ? 0
            : (nextMode === "results" ? 8 : -8)
    };
}
