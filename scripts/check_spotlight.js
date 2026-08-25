#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const spotlightRoot = path.join(__dirname, "..", "Titonium", "Modules", "Spotlight");

function loadDomain(name) {
    const sourcePath = path.join(spotlightRoot, name + ".js");
    if (!fs.existsSync(sourcePath)) {
        console.error(`FAIL spotlight domain: ${name}.js is missing`);
        process.exit(1);
    }
    const context = { Math };
    vm.createContext(context);
    const source = fs.readFileSync(sourcePath, "utf8").replace(/^\.pragma library\s*/, "");
    vm.runInContext(source, context, { filename: sourcePath });
    return context;
}

function assertEqual(actual, expected, label) {
    if (actual !== expected) {
        console.error(`FAIL ${label}: expected ${expected}, received ${actual}`);
        process.exit(1);
    }
}

function assertDeepEqual(actual, expected, label) {
    const received = JSON.stringify(actual);
    const wanted = JSON.stringify(expected);
    if (received !== wanted) {
        console.error(`FAIL ${label}: expected ${wanted}, received ${received}`);
        process.exit(1);
    }
}

function ids(count) {
    return Array.from({ length: count }, (_, index) => "app-" + (index + 1));
}

function groupFor(catalog, categoryId) {
    return catalog.find(group => group.id === categoryId);
}

const layout = loadDomain("SpotlightLayout");
const categories = loadDomain("CategoryCatalog");
const search = loadDomain("SearchEngine");
const calculator = loadDomain("Calculator");
const state = loadDomain("SpotlightState");

assertEqual(layout.columnCount(), 5, "fixed column count");
assertEqual(layout.rowCount(), 4, "fixed row count");
assertEqual(layout.pageSize(), 20, "fixed page capacity");
assertDeepEqual(Array.from(layout.pages(ids(21), 20), page => Array.from(page).length), [20, 1], "fixed pagination");
assertEqual(layout.indicatorWidth(ids(20), 20), 40, "full-page indicator width");
assertEqual(layout.indicatorWidth(ids(5), 20), 16, "quarter-page indicator width");

assertDeepEqual(Array.from(categories.idsFor(["Development", "Utility"])), ["development", "utilities"], "development and utility aliases");
assertDeepEqual(Array.from(categories.idsFor(["Network"])), ["internet"], "network alias");
assertDeepEqual(Array.from(categories.idsFor(["AudioVideo"])), ["multimedia"], "audio-video alias");
assertDeepEqual(Array.from(categories.idsFor(["Unrecognized"])), ["other"], "fallback category");

const catalogApps = [
    { id: "zeta.desktop", name: "Zeta", categories: ["Development", "Utility"] },
    { id: "alpha.desktop", name: "Alpha", categories: ["Development"] },
    { id: "omega.desktop", name: "Omega", categories: ["Game"] },
    { id: "browser.desktop", name: "Browser", categories: ["Network"] },
    { id: "player.desktop", name: "Player", categories: ["AudioVideo"] },
    { id: "writer.desktop", name: "Writer", categories: ["Office"] },
    { id: "monitor.desktop", name: "Monitor", categories: ["System"] },
    { id: "misc.desktop", name: "Misc", categories: ["Unrecognized"] }
];
const catalog = categories.catalogFor(catalogApps);
assertDeepEqual(Array.from(catalog, group => group.id), ["all", "development", "games", "internet", "multimedia", "office", "system", "utilities", "other"], "category order omits empty graphics");
assertDeepEqual(Array.from(groupFor(catalog, "all").apps, app => app.name), ["Alpha", "Browser", "Misc", "Monitor", "Omega", "Player", "Writer", "Zeta"], "all category alphabetizes names");
assertDeepEqual(Array.from(groupFor(catalog, "development").apps, app => app.name), ["Alpha", "Zeta"], "development category alphabetizes names");
assertDeepEqual(Array.from(groupFor(catalog, "utilities").apps, app => app.name), ["Zeta"], "multi-category app appears in utilities");
assertDeepEqual(Array.from(categories.catalogFor([])), [], "empty catalog has no categories");

const apps = [
    {
        id: "firefox.desktop",
        name: "Firefox",
        subtitle: "Web Browser",
        searchText: "firefox web browser",
        icon: "firefox",
        categories: ["Network"]
    },
    {
        id: "terminal.desktop",
        name: "Terminal",
        subtitle: "Command Line",
        searchText: "terminal command line shell",
        icon: "utilities-terminal",
        categories: ["System"]
    },
    {
        id: "terminology.desktop",
        name: "Terminology",
        subtitle: "Terminal Emulator",
        searchText: "terminology terminal emulator",
        icon: "utilities-terminal",
        categories: ["System"]
    }
];
assertDeepEqual(Array.from(search.search(apps, "fire"), item => item.id), ["firefox.desktop"], "search finds Firefox");
assertEqual(search.search(apps, "term")[0].type, "application", "search normalizes application type");
assertDeepEqual(Object.keys(search.search(apps, "fire")[0]).sort(), ["executionId", "icon", "id", "score", "subtitle", "title", "type"], "search result record shape");
assertDeepEqual(Array.from(search.search(apps, "term"), item => item.id), ["terminal.desktop", "terminology.desktop"], "prefix rank breaks ties alphabetically");
assertDeepEqual(Array.from(search.search(apps, "browser"), item => item.id), ["firefox.desktop"], "search matches complete catalog subtitles");

assertEqual(calculator.evaluate("2 + 3 * 4").value, "14", "calculator respects multiplication precedence");
assertEqual(calculator.evaluate("sqrt(81) + 1").value, "10", "calculator evaluates square roots");
assertEqual(calculator.evaluate("process.exit()").matched, false, "calculator rejects unsafe syntax");
assertEqual(calculator.evaluate("hello").matched, false, "calculator rejects non-expressions");

assertEqual(state.withQuery({ mode: "browse", categoryId: "games" }, "fire").mode, "results", "query enters results mode");
assertEqual(state.escape({ mode: "results", query: "fire", categoryId: "games" }).mode, "browse", "escape leaves results mode");
assertEqual(state.escape({ mode: "browse", query: "", categoryId: "games" }).closeRequested, true, "escape requests close from browse mode");
assertDeepEqual(state.initial("browse"), { mode: "browse", query: "", categoryId: "all", closeRequested: false }, "initial browse state");

console.log("PASS spotlight domain fixtures (28)");
