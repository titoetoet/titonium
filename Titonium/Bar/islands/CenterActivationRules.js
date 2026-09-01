.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function intent(source) {
    var normalized = text(source);
    if (normalized === "media")
        return "raise-media";
    return normalized === "clipboard" ? "open-clipboard" : "open-center";
}
