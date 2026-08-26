#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const spotlightRoot = path.join(__dirname, "..", "Titonium", "Overlays", "Spotlight");

function loadDomain(name, globals = {}) {
    const sourcePath = path.join(spotlightRoot, name + ".js");
    if (!fs.existsSync(sourcePath)) {
        console.error(`FAIL spotlight domain: ${name}.js is missing`);
        process.exit(1);
    }
    const context = { Math, ...globals };
    vm.createContext(context);
    const source = fs.readFileSync(sourcePath, "utf8")
        .replace(/^\.pragma library\s*/, "")
        .replace(/^\.import .*$/gm, "");
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
const stableOrder = loadDomain("StableOrder");
const transition = loadDomain("SpotlightTransition");
const categories = loadDomain("CategoryCatalog", { StableOrder: stableOrder });
const search = loadDomain("SearchEngine", { StableOrder: stableOrder });
const calculator = loadDomain("Calculator");
const state = loadDomain("SpotlightState");
const scope = loadDomain("SpotlightScope");

assertEqual(scope.next("applications", 1), "clipboard", "Tab advances Apps to Clipboard");
assertEqual(scope.next("clipboard", 1), "system", "Tab advances Clipboard to System Search");
assertEqual(scope.next("system", 1), "applications", "Tab wraps System Search to Apps");
assertEqual(scope.next("applications", -1), "system", "Shift+Tab reverses the scope cycle");
assertEqual(scope.next("unknown", 1), "clipboard", "unknown scope normalizes to Apps before cycling");
assertEqual(scope.modeFor("applications", ""), "browse", "empty Apps query shows the grid");
assertEqual(scope.modeFor("applications", "fire"), "results", "Apps query shows results");
assertEqual(scope.modeFor("clipboard", "fire"), "clipboard", "Clipboard query stays in Clipboard");
assertEqual(scope.modeFor("system", "fire"), "system", "System Search query stays in its mock scope");

assertEqual(layout.columnCount(), 5, "fixed column count");
assertEqual(layout.rowCount(), 4, "fixed row count");
assertEqual(layout.pageSize(), 20, "fixed page capacity");
assertDeepEqual(Array.from(layout.pages(ids(21), 20), page => Array.from(page).length), [20, 1], "fixed pagination");
assertEqual(typeof layout.indicatorTargetWidth, "function", "density indicator exposes a stable hit target");
assertEqual(typeof layout.indicatorVisualWidth, "function", "density indicator exposes proportional visual width");
assertEqual(layout.indicatorTargetWidth(), 56, "density indicator keeps a stable hit target");
assertEqual(layout.indicatorVisualWidth(ids(20), 20), 56, "full page uses the longest density pill");
assertEqual(layout.indicatorVisualWidth(ids(5), 20), 23, "quarter page uses a visibly shorter pill");
assertEqual(layout.indicatorVisualWidth([], 20), 12, "empty page keeps a visible minimum pill");

assertDeepEqual(Array.from(categories.idsFor(["Development", "Utility"])), ["development", "utilities"], "development and utility aliases");
assertDeepEqual(Array.from(categories.idsFor(["Network"])), ["internet"], "network alias");
assertDeepEqual(Array.from(categories.idsFor(["AudioVideo"])), ["multimedia"], "audio-video alias");
assertDeepEqual(Array.from(categories.idsFor(["WordProcessor"])), ["office"], "word processor alias");
assertDeepEqual(Array.from(categories.idsFor(["Settings"])), ["system"], "settings alias");
assertDeepEqual(Array.from(categories.idsFor(["FileManager"])), ["utilities"], "file manager alias");
assertDeepEqual(Array.from(categories.idsFor(["WebBrowser"])), ["internet"], "web browser alias");
assertDeepEqual(Array.from(categories.idsFor(["Audio", "Video"])), ["multimedia"], "audio-video subcategory aliases dedupe");
assertDeepEqual(Array.from(categories.idsFor(["IDE", "Building"])), ["development"], "development subcategory aliases dedupe");
assertDeepEqual(Array.from(categories.idsFor(["Unrecognized"])), ["other"], "fallback category");

const catalogApps = [
    { id: "zeta.desktop", name: "Zeta", categories: ["Development", "Utility"] },
    { id: "alpha.desktop", name: "Alpha", categories: ["Development"] },
    { id: "omega.desktop", name: "Omega", categories: ["Game"] },
    { id: "browser.desktop", name: "Browser", categories: ["Network"] },
    { id: "player.desktop", name: "Player", categories: ["AudioVideo"] },
    { id: "writer.desktop", name: "Writer", categories: ["Office"] },
    { id: "monitor.desktop", name: "Monitor", categories: ["System"] },
    { id: "misc.desktop", name: "Misc", categories: ["Unrecognized"] },
    { id: "accent.desktop", name: "Álpha", categories: ["Development"] },
    { id: "eclair.desktop", name: "Éclair", categories: ["Office"] }
];
const catalog = categories.catalogFor(catalogApps);
assertDeepEqual(Array.from(catalog, group => group.id), ["all", "development", "games", "internet", "multimedia", "office", "system", "utilities", "other"], "category order omits empty graphics");
assertDeepEqual(Array.from(groupFor(catalog, "all").apps, app => app.name), ["Alpha", "Browser", "Misc", "Monitor", "Omega", "Player", "Writer", "Zeta", "Álpha", "Éclair"], "all category uses stable code-point order for accented names");
assertDeepEqual(Array.from(groupFor(catalog, "development").apps, app => app.name), ["Alpha", "Zeta", "Álpha"], "development category uses stable code-point order");
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
    },
    {
        id: "alpha-editor.desktop",
        name: "Alpha",
        subtitle: "Editor",
        searchText: "alpha editor",
        icon: "accessories-text-editor",
        categories: ["Utility"]
    },
    {
        id: "accent-editor.desktop",
        name: "Álpha",
        subtitle: "Editor",
        searchText: "álpha editor",
        icon: "accessories-text-editor",
        categories: ["Utility"]
    },
    {
        id: "zulu-editor.desktop",
        name: "Zulu",
        subtitle: "Editor",
        searchText: "zulu editor",
        icon: "accessories-text-editor",
        categories: ["Utility"]
    }
];
assertDeepEqual(Array.from(search.search(apps, "fire"), item => item.id), ["firefox.desktop"], "search finds Firefox");
assertEqual(search.search(apps, "fire")[0].score, 3, "title-prefix matches use ranking tier three");
assertEqual(search.search(apps, "fox")[0].score, 2, "title-substring matches use ranking tier two");
assertEqual(search.search(apps, "browser")[0].score, 1, "metadata-only matches use ranking tier one");
assertDeepEqual(Array.from(search.search(apps, "no-match")), [], "unmatched applications do not enter a ranking tier");
assertEqual(search.search(apps, "term")[0].type, "application", "search normalizes application type");
assertDeepEqual(Object.keys(search.search(apps, "fire")[0]).sort(), ["executionId", "icon", "id", "score", "subtitle", "title", "type"], "search result record shape");
assertDeepEqual(Array.from(search.search(apps, "term"), item => item.id), ["terminal.desktop", "terminology.desktop"], "prefix rank breaks ties alphabetically");
assertDeepEqual(Array.from(search.search(apps, "browser"), item => item.id), ["firefox.desktop"], "search matches complete catalog subtitles");
assertDeepEqual(Array.from(search.search(apps, "editor"), item => item.title), ["Alpha", "Zulu", "Álpha"], "search ties use stable code-point order for accented names");
assertEqual(stableOrder.compare("Zulu", "Álpha"), -1, "stable comparator is locale independent");

assertDeepEqual(transition.plan("browse", "results", false, "slide-fade", 500), {
    animated: true,
    duration: 220,
    startOpacity: 0,
    startOffset: 8
}, "grid-to-results transition is short and bounded");
assertEqual(transition.plan("results", "browse", false, "slide", 120).startOffset, -8, "results-to-grid reverses position offset");
assertEqual(transition.plan("browse", "results", true, "slide-fade", 220).animated, false, "reduced motion disables grid-result motion");
assertEqual(transition.plan("browse", "results", false, "none", 220).duration, 0, "none transition has zero duration");
assertEqual(transition.plan("results", "clipboard", false, "slide-fade", 220).animated, false, "Clipboard branch does not inherit grid-result motion");

assertEqual(calculator.evaluate("2 + 3 * 4").value, "14", "calculator respects multiplication precedence");
assertEqual(calculator.evaluate("sqrt(81) + 1").value, "10", "calculator evaluates square roots");
assertEqual(calculator.evaluate("10 % 4").value, "2", "calculator evaluates remainder");
assertEqual(calculator.evaluate("2 ^ 3").value, "8", "calculator evaluates exponentiation");
assertEqual(calculator.evaluate("-2 ^ 2").value, "-4", "unary minus follows exponent precedence");
assertEqual(calculator.evaluate("pi").value, "3.141592653589793", "calculator exposes pi");
assertEqual(calculator.evaluate("sin(0)").value, "0", "calculator evaluates sine");
assertEqual(calculator.evaluate("cos(0)").value, "1", "calculator evaluates cosine");
assertEqual(calculator.evaluate("(2 + 3) * 4").value, "20", "calculator evaluates parentheses");
assertEqual(calculator.evaluate("2 +").matched, false, "calculator rejects incomplete expressions");
assertEqual(calculator.evaluate("1 / 0").matched, false, "calculator rejects infinite results");
assertEqual(calculator.evaluate("sqrt(-1)").matched, false, "calculator rejects non-finite results");
assertEqual(calculator.evaluate("process.exit()").matched, false, "calculator rejects unsafe syntax");
assertEqual(calculator.evaluate("hello").matched, false, "calculator rejects non-expressions");

assertEqual(state.withQuery({ mode: "browse", categoryId: "games" }, "fire").mode, "results", "query enters results mode");
assertEqual(state.escape({ mode: "results", query: "fire", categoryId: "games" }).mode, "browse", "escape leaves results mode");
assertEqual(state.escape({ mode: "browse", query: "", categoryId: "games" }).closeRequested, true, "escape requests close from browse mode");
assertDeepEqual(state.initial("browse"), { mode: "browse", query: "", categoryId: "all", closeRequested: false }, "initial browse state");

console.log("PASS spotlight domain fixtures (68)");
