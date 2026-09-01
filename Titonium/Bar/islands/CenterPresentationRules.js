.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function leadingIcon(eventPresentation, activityPresentation) {
    var icon = eventPresentation && typeof eventPresentation === "object"
        ? text(eventPresentation.icon) : "";
    if (icon)
        return icon;
    icon = activityPresentation && typeof activityPresentation === "object"
        ? text(activityPresentation.icon) : "";
    return icon || "center_focus_strong";
}
