.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function cleanTitle(app, context) {
    if (!app || !context)
        return context;
    const escapedApp = app.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const middlePattern = new RegExp(`\\s+-\\s+${escapedApp}\\s+-\\s+`, "i");
    if (middlePattern.test(context))
        return context.replace(middlePattern, " - ");
    return context;
}

function contextText(app, context) {
    const value = text(context);
    if (!value || value.toLocaleLowerCase() === app.toLocaleLowerCase())
        return "";
    return cleanTitle(app, value);
}

function label(appName, context) {
    const app = text(appName) || "Titonium";
    const detail = contextText(app, context);
    if (!detail)
        return app;
    return app + " · " + detail;
}

function presentation(appName, trayContext, windowTitle, hasTrayMenu) {
    const app = text(appName) || "Titonium";
    const source = (hasTrayMenu === true && text(trayContext))
        ? text(trayContext)
        : (hasTrayMenu === true && app.toLocaleLowerCase() === "chatgpt" ? "" : windowTitle);
    const detail = contextText(app, source);
    return {
        appName: app,
        title: detail,
        hasContext: detail.length > 0,
    };
}
