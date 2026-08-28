.pragma library

function canYield(settingsActive, savePending) {
    return settingsActive !== true || savePending !== true;
}
