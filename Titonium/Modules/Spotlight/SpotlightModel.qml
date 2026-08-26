pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Foundation
import qs.Titonium.Platform.Applications
import qs.Titonium.Platform.Clipboard
import "Calculator.js" as Calculator
import "CategoryCatalog.js" as CategoryCatalog
import "SearchEngine.js" as SearchEngine
import "SpotlightLayout.js" as SpotlightLayout
import "SpotlightScope.js" as SpotlightScope
import "SpotlightState.js" as SpotlightState

QtObject {
    id: root

    property string mode: "browse"
    property string scope: "applications"
    property string query: ""
    property string categoryId: "all"
    property int pageIndex: 0
    property int selectedIndex: 0
    property bool selectionMoved: false

    readonly property var categories: CategoryCatalog.catalogFor(ApplicationVisibilityStore.visibleApplications)
    readonly property var visibleApps: {
        for (let index = 0; index < root.categories.length; index++) {
            if (root.categories[index].id === root.categoryId)
                return root.categories[index].apps;
        }
        return [];
    }
    readonly property var pages: SpotlightLayout.pages(root.visibleApps, SpotlightLayout.pageSize())
    readonly property var results: root.searchResults()

    function open(descriptorMode: string): void {
        root.scope = SpotlightScope.normalize(descriptorMode);
        const initial = SpotlightState.initial(descriptorMode === "results" ? "results" : "browse");
        root.query = initial.query;
        root.mode = SpotlightScope.modeFor(root.scope, root.query);
        root.categoryId = initial.categoryId;
        root.pageIndex = 0;
        root.selectedIndex = 0;
        root.selectionMoved = false;
    }

    function setQuery(nextQuery: string): void {
        if (root.scope !== "applications") {
            root.query = typeof nextQuery === "string" ? nextQuery : "";
            root.mode = SpotlightScope.modeFor(root.scope, root.query);
            root.selectedIndex = 0;
            root.selectionMoved = false;
            return;
        }
        const next = SpotlightState.withQuery({
            "mode": root.mode,
            "query": root.query,
            "categoryId": root.categoryId
        }, nextQuery);
        root.query = next.query;
        root.mode = next.mode;
        root.categoryId = next.categoryId;
        root.selectedIndex = 0;
        root.selectionMoved = false;
    }

    function cycleScope(delta: int): void {
        root.scope = SpotlightScope.next(root.scope, delta);
        root.mode = SpotlightScope.modeFor(root.scope, root.query);
        root.pageIndex = 0;
        root.selectedIndex = 0;
        root.selectionMoved = false;
    }

    function setCategory(nextCategoryId: string): void {
        if (!nextCategoryId || nextCategoryId === root.categoryId)
            return;
        for (let index = 0; index < root.categories.length; index++) {
            if (root.categories[index].id === nextCategoryId) {
                root.categoryId = nextCategoryId;
                root.pageIndex = 0;
                return;
            }
        }
    }

    function setPage(nextPage: int): void {
        root.pageIndex = Math.max(0, Math.min(root.pages.length - 1, nextPage));
    }

    function searchResults(): var {
        if (root.mode !== "results")
            return [];
        const applications = SearchEngine.search(ApplicationVisibilityStore.visibleApplications, root.query);
        const calculation = Calculator.evaluate(root.query);
        if (!calculation.matched)
            return applications;
        return [{
            "id": "calculator:" + calculation.value,
            "type": "calculator",
            "title": calculation.value,
            "subtitle": I18n.tr("spotlight.calculator_result"),
            "icon": "calculate",
            "score": 4,
            "executionId": calculation.value,
            "value": calculation.value
        }].concat(applications);
    }

    function moveSelection(delta: int): void {
        if (root.results.length === 0)
            return;
        const length = root.results.length;
        root.selectedIndex = (root.selectedIndex + delta + length) % length;
        root.selectionMoved = true;
    }

    function selectResult(index: int): void {
        if (index < 0 || index >= root.results.length)
            return;
        root.selectedIndex = index;
        root.selectionMoved = true;
    }

    function activateSelected(): bool {
        if (root.results.length === 0)
            return false;
        const index = root.selectionMoved ? root.selectedIndex : 0;
        const result = root.results[index];
        if (result.type === "calculator")
            return ClipboardAdapter.copy(result.value);
        return ApplicationCatalog.launch(result.executionId);
    }

    function activateApplication(entryId: string): bool {
        return ApplicationCatalog.launch(entryId);
    }

    function handleEscape(): bool {
        if (root.mode === "clipboard") {
            root.selectedIndex = 0;
            root.selectionMoved = false;
            return true;
        }
        const next = SpotlightState.escape({
            "mode": root.mode,
            "query": root.query,
            "categoryId": root.categoryId
        });
        root.mode = next.mode;
        root.query = next.query;
        root.categoryId = next.categoryId;
        root.selectedIndex = 0;
        root.selectionMoved = false;
        return next.closeRequested;
    }
}
