.pragma library

function normalizePage(pageId) {
    if (pageId === "banner")
        return pageId;
    return "overview";
}

function entryPage(source) {
    return String(source || "") === "agent" ? "overview" : "banner";
}

function visualState(active, pageId, activityCount) {
    if (active)
        return normalizePage(pageId) === "banner" ? "banner" : "expanded";
    return Number(activityCount) >= 1 ? "satellite" : "compact";
}

function activitySlots(activities, focusActivity, secondaryOverride, focusEnabled) {
    const source = Array.isArray(activities) ? activities : [];
    const focusOwnsPrimary = focusEnabled !== false
        && focusActivity && typeof focusActivity === "object";
    let primary = focusOwnsPrimary ? focusActivity : null;
    if (!primary) {
        for (let index = 0; index < source.length; index++) {
            if (source[index]?.source === "media") {
                primary = source[index];
                break;
            }
        }
        if (!primary && source.length > 0)
            primary = source[0];
    }
    let secondary = secondaryOverride && typeof secondaryOverride === "object"
        ? secondaryOverride : null;
    if (!secondary) {
        for (let index = 0; index < source.length; index++) {
            if (!primary || source[index]?.id !== primary.id) {
                secondary = source[index];
                break;
            }
        }
    }
    return Object.freeze({
        primary: primary,
        secondary: secondary
    });
}

function layoutProfile(screenWidth, screenHeight) {
    const width = Math.max(0, Number(screenWidth) || 0);
    const height = Math.max(1, Number(screenHeight) || 1);
    const ultrawide = width / height >= 2.1;
    const compactHeight = ultrawide ? 42 : 36;
    return Object.freeze({
        compactHeight: compactHeight,
        primaryMinWidth: 180,
        primaryMaxWidth: ultrawide ? 340 : 260,
        nestedMaxWidth: ultrawide ? 340 : 320,
        gap: 8,
        ultrawide: ultrawide
    });
}

function connectedBodyWidth(visualWidth, shoulderSize) {
    const width = Math.max(0, Number(visualWidth) || 0);
    const shoulder = Math.max(0, Number(shoulderSize) || 0);
    return Math.max(0, width - shoulder * 2);
}

function compactPrimaryWidth(contentWidth, maximumWidth) {
    const maximum = Math.max(180, Number(maximumWidth) || 260);
    return Math.max(180, Math.min(maximum, Number(contentWidth) || 0));
}

function dragSettlePlan(progress, offset, velocity) {
    const current = Math.max(0, Math.min(1, Number(progress) || 0));
    const targetState = dragDecision(offset, velocity);
    const targetProgress = targetState === "expanded" ? 1 : 0;
    const distance = Math.abs(targetProgress - current);
    return Object.freeze({
        targetState: targetState,
        targetProgress: targetProgress,
        duration: Math.round(90 + distance * 90)
    });
}

function contextForActivity(activity) {
    if (!activity || typeof activity !== "object")
        return Object.freeze({ source: "idle", id: "", title: "" });
    return Object.freeze({
        source: String(activity.source || "idle"),
        id: String(activity.id || ""),
        title: String(activity.label || activity.title || ""),
        icon: String(activity.icon || "bolt")
    });
}

function dragDecision(offset, velocity) {
    const distance = Math.max(0, Number(offset) || 0);
    const speed = Math.max(0, Number(velocity) || 0);
    return distance >= 48 || speed >= 500 ? "expanded" : "banner";
}

function shouldAutoOpen(state, source, urgency) {
    if (state !== "compact" && state !== "satellite")
        return false;
    if (source === "agent")
        return true;
    return source === "notification" && Number(urgency) >= 2;
}
