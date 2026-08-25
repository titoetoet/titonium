.pragma library

function normalizedText(value) {
    return String(value || "").toLocaleLowerCase();
}

function resultFor(app, score) {
    return {
        id: String(app.id || ""),
        type: "application",
        title: String(app.title || app.name || app.id || ""),
        subtitle: String(app.subtitle || app.genericName || app.comment || ""),
        icon: String(app.icon || ""),
        score: score,
        executionId: String(app.executionId || app.id || "")
    };
}

function scoreFor(app, query) {
    const title = normalizedText(app.title || app.name || app.id);
    if (title.indexOf(query) === 0)
        return 3;
    if (title.indexOf(query) !== -1)
        return 2;

    const searchText = normalizedText(app.searchText || "");
    const subtitle = normalizedText(app.subtitle || app.genericName || app.comment || "");
    return searchText.indexOf(query) !== -1 || subtitle.indexOf(query) !== -1 ? 1 : 0;
}

function compareResults(left, right) {
    if (left.score !== right.score)
        return right.score - left.score;
    const titleComparison = left.title.localeCompare(right.title);
    if (titleComparison !== 0)
        return titleComparison;
    return left.id.localeCompare(right.id);
}

function search(apps, query) {
    const normalizedQuery = normalizedText(query).trim();
    if (!normalizedQuery || !Array.isArray(apps))
        return [];

    const results = [];
    for (let index = 0; index < apps.length; index++) {
        const app = apps[index];
        if (!app)
            continue;
        const score = scoreFor(app, normalizedQuery);
        if (score > 0)
            results.push(resultFor(app, score));
    }
    return results.sort(compareResults);
}
