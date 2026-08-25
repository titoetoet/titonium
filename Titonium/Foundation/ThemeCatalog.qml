pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "JsonTools.js" as JsonTools
import "ConfigValidator.js" as Validator

QtObject {
    id: root

    property var catalogState: ({})
    property var themeCache: ({})
    property var availableThemes: []
    property bool ready: false
    property string lastError: ""

    readonly property string defaultThemeId: root.catalogState.defaultThemeId || "titonium-neutral"

    function parseFile(fileView: FileView, label: string): var {
        const text = fileView.text();
        if (!text || text.trim().length === 0) {
            Logger.error("theme", label + " is empty");
            return null;
        }
        try {
            return JSON.parse(text);
        } catch (error) {
            Logger.error("theme", label + " contains invalid JSON: " + error);
            return null;
        }
    }

    function initialize(): bool {
        const catalog = root.parseFile(indexFile, "theme catalog");
        const errors = Validator.validateThemeCatalog(catalog);
        if (errors.length > 0) {
            root.lastError = errors.join("; ");
            Logger.error("theme", "catalog rejected: " + root.lastError);
            root.ready = false;
            return false;
        }
        root.catalogState = JsonTools.clone(catalog);
        root.themeCache = {};
        root.lastError = "";
        root.ready = true;
        const available = [];
        const entries = root.catalogState.themes || [];
        for (let index = 0; index < entries.length; index++) {
            const theme = root.loadEntry(entries[index]);
            if (theme) {
                available.push({
                    "id": theme.id,
                    "nameKey": theme.nameKey,
                    "descriptionKey": theme.descriptionKey || "",
                    "immutable": theme.immutable
                });
            }
        }
        root.availableThemes = available;
        return true;
    }

    function entryFor(themeId: string): var {
        const entries = root.catalogState.themes || [];
        for (let index = 0; index < entries.length; index++) {
            if (entries[index].id === themeId)
                return entries[index];
        }
        return null;
    }

    function loadEntry(entry: var): var {
        if (!entry)
            return null;
        if (root.themeCache[entry.id])
            return JsonTools.clone(root.themeCache[entry.id]);
        packageFile.path = Quickshell.shellPath("config/themes/" + entry.file);
        const document = root.parseFile(packageFile, "theme " + entry.id);
        const errors = Validator.validateTheme(document);
        if (errors.length > 0) {
            Logger.warn("theme", "package " + entry.id + " rejected: " + errors.join("; "));
            return null;
        }
        if (document.id !== entry.id) {
            Logger.warn("theme", "package ID does not match catalog entry: " + entry.id);
            return null;
        }
        const nextCache = JsonTools.clone(root.themeCache);
        nextCache[entry.id] = JsonTools.clone(document);
        root.themeCache = nextCache;
        return document;
    }

    function themeFor(themeId: string): var {
        if (!root.ready && !root.initialize())
            return {};
        const requested = root.loadEntry(root.entryFor(themeId));
        if (requested)
            return JsonTools.clone(requested);
        if (themeId !== root.defaultThemeId)
            Logger.warn("theme", "falling back from " + themeId + " to " + root.defaultThemeId);
        const fallback = root.loadEntry(root.entryFor(root.defaultThemeId));
        return fallback ? JsonTools.clone(fallback) : {};
    }

    Component.onCompleted: root.initialize()

    property FileView indexFile: FileView {
        path: Quickshell.shellPath("config/themes/index.json")
        preload: false
        blockLoading: true
    }

    property FileView packageFile: FileView {
        path: ""
        preload: false
        // The path changes while walking the catalog. blockLoading may return
        // the previously loaded package after a path change; blockAllReads
        // guarantees this startup-only reader parses the requested tiny file.
        blockAllReads: true
    }
}
