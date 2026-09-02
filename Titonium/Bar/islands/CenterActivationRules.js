.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function intent(source) {
    var normalized = text(source);
    if (normalized === "media")
        return "raise-media";
    if (normalized === "clipboard")
        return "open-clipboard";
    return normalized === "notification" ? "open-notifications" : "open-center";
}
