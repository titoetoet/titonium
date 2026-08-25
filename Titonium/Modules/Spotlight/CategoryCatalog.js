.pragma library
.import "StableOrder.js" as StableOrder

const CATEGORY_DEFINITIONS = [
    { id: "all", title: "All", aliases: [] },
    { id: "development", title: "Development", aliases: ["development"] },
    { id: "games", title: "Games", aliases: ["game", "games"] },
    { id: "graphics", title: "Graphics", aliases: ["graphics"] },
    { id: "internet", title: "Internet", aliases: ["network", "internet"] },
    { id: "multimedia", title: "Multimedia", aliases: ["audiovideo", "multimedia"] },
    { id: "office", title: "Office", aliases: ["office"] },
    { id: "system", title: "System", aliases: ["system"] },
    { id: "utilities", title: "Utilities", aliases: ["utility", "utilities"] },
    { id: "other", title: "Other", aliases: [] }
];

function idsFor(categories) {
    const source = Array.isArray(categories) ? categories : [];
    const aliases = {};
    for (let index = 0; index < source.length; index++)
        aliases[String(source[index] || "").trim().toLowerCase()] = true;

    const ids = [];
    for (let index = 1; index < CATEGORY_DEFINITIONS.length - 1; index++) {
        const definition = CATEGORY_DEFINITIONS[index];
        for (let aliasIndex = 0; aliasIndex < definition.aliases.length; aliasIndex++) {
            if (aliases[definition.aliases[aliasIndex]]) {
                ids.push(definition.id);
                break;
            }
        }
    }
    return ids.length > 0 ? ids : ["other"];
}

function compareApps(left, right) {
    const leftName = String(left?.name || left?.title || left?.id || "");
    const rightName = String(right?.name || right?.title || right?.id || "");
    const comparison = StableOrder.compare(leftName, rightName);
    if (comparison !== 0)
        return comparison;
    return StableOrder.compare(String(left?.id || ""), String(right?.id || ""));
}

function catalogFor(apps) {
    const source = Array.isArray(apps) ? apps.filter(app => app) : [];
    if (source.length === 0)
        return [];

    const groups = {};
    for (let index = 0; index < CATEGORY_DEFINITIONS.length; index++)
        groups[CATEGORY_DEFINITIONS[index].id] = [];

    for (let index = 0; index < source.length; index++) {
        const app = source[index];
        groups.all.push(app);
        const appIds = idsFor(app.categories);
        for (let idIndex = 0; idIndex < appIds.length; idIndex++)
            groups[appIds[idIndex]].push(app);
    }

    const catalog = [];
    for (let index = 0; index < CATEGORY_DEFINITIONS.length; index++) {
        const definition = CATEGORY_DEFINITIONS[index];
        const groupApps = groups[definition.id];
        if (groupApps.length === 0)
            continue;
        groupApps.sort(compareApps);
        catalog.push({ id: definition.id, title: definition.title, apps: groupApps });
    }
    return catalog;
}
