.pragma library

function text(value) {
    return typeof value === "string" ? value.trim() : "";
}

function label(appName, title) {
    const app = text(appName);
    const task = text(title);
    if (!app && !task)
        return "Titonium";
    if (!app)
        return task;
    if (!task || task.toLocaleLowerCase() === app.toLocaleLowerCase())
        return app;
    return app + " · " + task;
}

function presentation(appName, title, activeLabel, desktopLabel) {
    const app = text(appName);
    const task = text(title);
    const active = text(activeLabel) || "Active";
    const desktop = text(desktopLabel) || "Desktop";
    if (!app && !task)
        return { appName: "Titonium", title: desktop };
    return {
        appName: app || "Titonium",
        title: !task || task.toLocaleLowerCase() === app.toLocaleLowerCase()
            ? active : task
    };
}
