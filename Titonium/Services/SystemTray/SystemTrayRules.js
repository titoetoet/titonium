.pragma library

var GENERIC_IDENTITY_TOKENS = Object.freeze({
    app: true,
    application: true,
    client: true,
    com: true,
    desktop: true,
    io: true,
    net: true,
    org: true,
    status: true,
    tray: true,
});

function text(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function normalizedText(value) {
    return text(value).toLocaleLowerCase();
}

function inputMenuIcon(value) {
    var label = normalizedText(value);
    if (label.indexOf("lotus") >= 0 || label.indexOf("vietnamese") >= 0
            || label.indexOf("tiếng việt") >= 0)
        return "local_florist";
    if (label.indexOf("add") >= 0 || label.indexOf("thêm") >= 0)
        return "add_circle";
    if (label.indexOf("remove") >= 0 || label.indexOf("xóa") >= 0
            || label.indexOf("xoá") >= 0)
        return "remove_circle";
    if (label.indexOf("disable") >= 0 || label.indexOf("deactivate") >= 0
            || label.indexOf("tắt") >= 0)
        return "toggle_off";
    if (label.indexOf("enable") >= 0 || label.indexOf("activate") >= 0
            || label.indexOf("bật") >= 0)
        return "toggle_on";
    if (label.indexOf("configure") >= 0 || label.indexOf("settings") >= 0
            || label.indexOf("cài đặt") >= 0)
        return "settings";
    if (label.indexOf("restart") >= 0 || label.indexOf("reload") >= 0
            || label.indexOf("khởi động lại") >= 0 || label.indexOf("nạp lại") >= 0)
        return "restart_alt";
    if (label.indexOf("about") >= 0 || label.indexOf("giới thiệu") >= 0)
        return "info";
    if (label.indexOf("help") >= 0 || label.indexOf("trợ giúp") >= 0)
        return "help";
    if (label.indexOf("exit") >= 0 || label.indexOf("quit") >= 0
            || label.indexOf("thoát") >= 0)
        return "logout";
    if (label.indexOf("keyboard") >= 0 || label.indexOf("english") >= 0
            || label.indexOf("language") >= 0 || label.indexOf("ngôn ngữ") >= 0)
        return "language";
    if (label.indexOf("charset") >= 0 || label.indexOf("character set") >= 0)
        return "translate";
    if (label.indexOf("spell check") >= 0 || label.indexOf("spelling") >= 0)
        return "spellcheck";
    if (label.indexOf("capitalize macro") >= 0)
        return "text_format";
    if (label.indexOf("macro") >= 0)
        return "code";
    if (label.indexOf("restore") >= 0)
        return "restore";
    if (label.indexOf("dictionary") >= 0)
        return "dictionary";
    return "keyboard_alt";
}

function inputMenuPresentation(raw) {
    var source = raw && typeof raw === "object" ? raw : {};
    var rawLabel = text(source.text);
    var enabled = /^[✔✓]\s*/.test(rawLabel);
    var disabled = /^[✖✕×]\s*/.test(rawLabel);
    var label = rawLabel.replace(/^[✔✓✖✕×]\s*/, "");
    return Object.freeze({
        label: label,
        icon: inputMenuIcon(label),
        selected: source.checked === true || (enabled && !disabled),
    });
}

function menuButtonType(value) {
    return value === "radio" || value === "checkbox" ? value : "none";
}

function identityTokens(value) {
    var expanded = text(value).replace(/([a-z0-9])([A-Z])/g, "$1 $2");
    var raw = expanded.toLocaleLowerCase().split(/[^a-z0-9]+/);
    var result = [];
    for (var index = 0; index < raw.length; index++) {
        var token = raw[index];
        if (token.length >= 3 && !GENERIC_IDENTITY_TOKENS[token])
            result.push(token);
    }
    return result;
}

function identityKeys(values) {
    var result = {};
    for (var valueIndex = 0; valueIndex < values.length; valueIndex++) {
        var tokens = identityTokens(values[valueIndex]);
        if (tokens.length > 0)
            result[tokens.join("")] = true;
    }
    return result;
}

function inputMethodIdentity(id, title, tooltipTitle) {
    var identity = normalizedText(id) + " " + normalizedText(title)
        + " " + normalizedText(tooltipTitle);
    return identity.indexOf("fcitx") >= 0;
}

function descriptor(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    var id = text(raw.id);
    if (!id)
        return null;
    var title = text(raw.title);
    return Object.freeze({
        id: id,
        title: title,
        tooltipTitle: text(raw.tooltipTitle),
        tooltipDescription: text(raw.tooltipDescription),
        icon: text(raw.icon),
        inputMethod: inputMethodIdentity(id, title, raw.tooltipTitle),
    });
}

function project(rawItems) {
    var source = Array.isArray(rawItems) ? rawItems : [];
    var result = [];
    for (var index = 0; index < source.length; index++) {
        var item = descriptor(source[index]);
        if (item !== null)
            result.push(item);
    }
    return Object.freeze(result);
}

function record(raw, nativeIndex) {
    if (!raw || typeof raw !== "object")
        return null;
    var id = text(raw.id);
    var title = text(raw.title);
    return Object.freeze({
        nativeIndex: nativeIndex,
        id: id,
        title: title,
        tooltipTitle: text(raw.tooltipTitle),
        tooltipDescription: text(raw.tooltipDescription),
        icon: text(raw.icon),
        inputMethod: inputMethodIdentity(id, title, raw.tooltipTitle),
        hasMenu: raw.hasMenu === true,
    });
}

function projectRecords(rawItems) {
    var source = Array.isArray(rawItems) ? rawItems : [];
    var result = [];
    for (var index = 0; index < source.length; index++) {
        var item = record(source[index], index);
        if (item !== null)
            result.push(item);
    }
    return Object.freeze(result);
}



function menuDescriptor(raw, index) {
    if (!raw || typeof raw !== "object")
        return null;
    return Object.freeze({
        index: index,
        text: text(raw.text),
        icon: text(raw.icon),
        enabled: raw.enabled === true,
        separator: raw.isSeparator === true,
        hasChildren: raw.hasChildren === true,
        buttonType: menuButtonType(raw.buttonType),
        checked: raw.checked === true,
    });
}

function projectMenuEntries(rawEntries) {
    var source = Array.isArray(rawEntries) ? rawEntries : [];
    var result = [];
    for (var index = 0; index < source.length; index++) {
        var entry = menuDescriptor(source[index], index);
        if (entry !== null)
            result.push(entry);
    }
    return Object.freeze(result);
}

function statusContext(entries) {
    var source = Array.isArray(entries) ? entries : [];
    for (var index = 0; index < source.length; index++) {
        var entry = source[index];
        if (!entry || entry.separator === true)
            continue;
        var content = text(entry.text);
        if (!content)
            continue;
        if (/^[1-9]\d*\s+agents?\s+running\b/i.test(content)
                || /^[1-9]\d*\s+(?:tasks?|jobs?)\s+(?:running|active|in progress)\b/i.test(content)
                || /^[1-9]\d*\s+(?:downloads?|uploads?|transfers?)\s+(?:running|in progress|active)\b/i.test(content)
                || /\b[1-9]\d*\s+active\s+(?:tasks?|jobs?|agents?|conversations?)\b/i.test(content)) {
            return content;
        }
    }
    return "";
}

function runningContext(entries) {
    var source = Array.isArray(entries) ? entries : [];
    var section = "";
    var recentContext = "";
    for (var index = 0; index < source.length; index++) {
        var entry = source[index];
        if (!entry)
            continue;
        if (entry.separator) {
            section = "";
            continue;
        }
        var label = normalizedText(entry.text);
        if (entry.enabled !== true
                && (label === "running" || label === "recent")) {
            section = label;
            continue;
        }
        if (entry.enabled !== true || !text(entry.text))
            continue;
        if (section === "running")
            return text(entry.text);
        if (section === "recent" && !recentContext)
            recentContext = text(entry.text);
    }
    if (recentContext)
        return recentContext;
    return statusContext(source);
}

function sameApplication(appId, appName, item) {
    var appKeys = identityKeys([appId, appName]);
    var itemKeys = identityKeys([item.id, item.title, item.tooltipTitle]);
    var keys = Object.keys(appKeys);
    for (var index = 0; index < keys.length; index++) {
        if (itemKeys[keys[index]] === true)
            return true;
    }
    return false;
}

function matchingIndex(appId, appName, descriptors) {
    var source = Array.isArray(descriptors) ? descriptors : [];
    for (var index = 0; index < source.length; index++) {
        var item = source[index];
        if (item && item.inputMethod !== true
                && sameApplication(appId, appName, item))
            return index;
    }
    return -1;
}

function hasMenuForApp(appId, appName, records) {
    var record = selectRecord(appId, appName, records);
    return !!record && record.hasMenu === true;
}

function popupEntryAction(entries, index) {
    var source = Array.isArray(entries) ? entries : [];
    var entry = Number.isInteger(index) ? source[index] : null;
    if (!entry || entry.separator === true || entry.enabled !== true)
        return "none";
    return entry.hasChildren === true ? "submenu" : "trigger";
}

function nextMenuSelection(currentSelection, appId, appName, records) {
    var requested = Object.freeze({ appId: text(appId), appName: text(appName) });
    var requestedRecord = selectRecord(requested.appId, requested.appName, records);
    if (requestedRecord && requestedRecord.hasMenu === true)
        return requested;
    var current = currentSelection && typeof currentSelection === "object"
        ? Object.freeze({
            appId: text(currentSelection.appId),
            appName: text(currentSelection.appName),
        })
        : Object.freeze({ appId: "", appName: "" });
    var currentRecord = selectRecord(current.appId, current.appName, records);
    return currentRecord && currentRecord.hasMenu === true ? current : requested;
}

function selectRecord(appId, appName, records) {
    var source = Array.isArray(records) ? records : [];
    var firstMatch = null;
    for (var index = 0; index < source.length; index++) {
        var item = source[index];
        if (!item || item.inputMethod === true
                || !sameApplication(appId, appName, item))
            continue;
        if (item.hasMenu === true)
            return item;
        if (firstMatch === null)
            firstMatch = item;
    }
    return firstMatch;
}

function selectedContext(selectedRecord, menuEntries, tooltipContext) {
    if (selectedRecord?.hasMenu === true)
        return runningContext(menuEntries);
    return text(tooltipContext);

}
function usefulContext(candidate, appName, item) {
    var value = text(candidate);
    if (!value)
        return "";
    var normalized = normalizedText(value);
    var redundant = [appName, item.id, item.title];
    for (var index = 0; index < redundant.length; index++) {
        if (normalized && normalized === normalizedText(redundant[index]))
            return "";
    }
    return value;
}

function contextForApp(appId, appName, descriptors) {
    var source = Array.isArray(descriptors) ? descriptors : [];
    for (var index = 0; index < source.length; index++) {
        var item = source[index];
        if (!item || item.inputMethod === true
                || !sameApplication(appId, appName, item))
            continue;
        var candidates = [
            item.tooltipDescription,
            item.tooltipTitle,
            item.title,
        ];
        for (var candidateIndex = 0; candidateIndex < candidates.length;
                candidateIndex++) {
            var context = usefulContext(candidates[candidateIndex], appName, item);
            if (context)
                return context;
        }
    }
    return "";
}

function inputMethodRecord(records) {
    var source = Array.isArray(records) ? records : [];
    for (var index = 0; index < source.length; index++) {
        if (source[index] && source[index].inputMethod === true)
            return source[index];
    }
    return null;
}

function inputMethod(descriptors) {
    var source = Array.isArray(descriptors) ? descriptors : [];
    for (var index = 0; index < source.length; index++) {
        if (source[index] && source[index].inputMethod === true)
            return source[index];
    }
    return null;
}
