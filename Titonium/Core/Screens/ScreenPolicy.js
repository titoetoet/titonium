.pragma library

function acceptsScreen(screen, targetScreenName) {
    return !!screen && typeof screen.name === "string"
        && targetScreenName.length > 0
        && screen.name === targetScreenName;
}

function eligibleScreens(screens, targetScreenName) {
    var eligible = [];
    if (!screens || targetScreenName.length === 0)
        return eligible;
    for (var index = 0; index < screens.length; index++) {
        if (acceptsScreen(screens[index], targetScreenName))
            eligible.push(screens[index]);
    }
    return eligible;
}
