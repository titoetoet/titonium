.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function contextText(app, context) {
    const value = text(context);
    if (!value || value.toLocaleLowerCase() === app.toLocaleLowerCase())
        return "";
    return value;
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
    const source = hasTrayMenu === true ? trayContext : windowTitle;
    const detail = contextText(app, source);
    return {
        appName: app,
        title: detail,
        hasContext: detail.length > 0,
    };
}
