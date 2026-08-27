.pragma library

function appIconSize() {
    return 56;
}

function appLabelSize() {
    return 14;
}

function categoryLabelSize() {
    return 15;
}

function categoryControlSize() {
    return "medium";
}

function searchTextSize() {
    return 15;
}

function fallbackIcon(categories) {
    const length = Math.max(0, Math.floor(Number(categories?.length) || 0));
    const normalized = [];
    for (let index = 0; index < length; index++)
        normalized.push(String(categories[index] || "").trim().toLowerCase());
    const mappings = [
        { aliases: ["development", "ide", "building"], icon: "code" },
        { aliases: ["network", "internet", "webbrowser", "remoteaccess"], icon: "public" },
        { aliases: ["audiovideo", "audio", "video", "player"], icon: "play_circle" },
        { aliases: ["graphics", "photography"], icon: "image" },
        { aliases: ["game", "games"], icon: "sports_esports" },
        { aliases: ["office", "wordprocessor", "spreadsheet", "presentation"], icon: "description" },
        { aliases: ["system", "settings", "desktopsettings"], icon: "settings" },
        { aliases: ["utility", "utilities", "filemanager", "calculator"], icon: "widgets" }
    ];
    for (let mappingIndex = 0; mappingIndex < mappings.length; mappingIndex++) {
        const mapping = mappings[mappingIndex];
        for (let aliasIndex = 0; aliasIndex < mapping.aliases.length; aliasIndex++) {
            if (normalized.indexOf(mapping.aliases[aliasIndex]) >= 0)
                return mapping.icon;
        }
    }
    return "widgets";
}
