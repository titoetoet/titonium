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
