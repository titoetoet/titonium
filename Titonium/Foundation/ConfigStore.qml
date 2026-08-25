pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "JsonTools.js" as JsonTools
import "ConfigValidator.js" as Validator

QtObject {
    id: root

    property var committedState: ({})
    property var previewState: ({})
    property var layoutState: ({})
    property var themeState: ({})
    property bool ready: false
    property bool previewActive: false
    property string lastError: ""

    readonly property string runtimeSettingsPath: Quickshell.dataPath("settings.json")
    readonly property string runtimeLayoutPath: Quickshell.dataPath("layout.json")

    function parseDocument(fileView: FileView, label: string): var {
        const text = fileView.text();
        if (!text || text.trim().length === 0)
            return null;
        try {
            return JSON.parse(text);
        } catch (error) {
            Logger.warn("config", label + " contains invalid JSON: " + error);
            return null;
        }
    }

    function initialize(): void {
        const defaultSettings = parseDocument(defaultSettingsFile, "default settings");
        const defaultLayout = parseDocument(defaultLayoutFile, "default layout");
        const defaultTheme = parseDocument(defaultThemeFile, "default theme");

        const settingsErrors = Validator.validateSettings(defaultSettings);
        const layoutErrors = Validator.validateLayout(defaultLayout);
        const themeErrors = Validator.validateTheme(defaultTheme);
        if (settingsErrors.length || layoutErrors.length || themeErrors.length) {
            root.lastError = settingsErrors.concat(layoutErrors, themeErrors).join("; ");
            Logger.error("config", "shipped configuration is invalid: " + root.lastError);
            return;
        }

        let selectedSettings = defaultSettings;
        const runtimeSettings = parseDocument(runtimeSettingsFile, "runtime settings");
        if (runtimeSettings) {
            const runtimeErrors = Validator.validateSettings(runtimeSettings);
            if (runtimeErrors.length === 0)
                selectedSettings = runtimeSettings;
            else
                Logger.warn("config", "runtime settings rejected: " + runtimeErrors.join("; "));
        }

        let selectedLayout = defaultLayout;
        const runtimeLayout = parseDocument(runtimeLayoutFile, "runtime layout");
        if (runtimeLayout) {
            const runtimeLayoutErrors = Validator.validateLayout(runtimeLayout);
            if (runtimeLayoutErrors.length === 0)
                selectedLayout = runtimeLayout;
            else
                Logger.warn("config", "runtime layout rejected: " + runtimeLayoutErrors.join("; "));
        }

        root.committedState = JsonTools.clone(selectedSettings);
        root.previewState = JsonTools.clone(selectedSettings);
        root.layoutState = JsonTools.clone(selectedLayout);
        root.themeState = JsonTools.clone(defaultTheme);
        root.lastError = "";
        root.ready = true;
        Logger.info("config", "schema v1 loaded from defaults/runtime data directory");
    }

    function beginPreview(): void {
        root.previewState = JsonTools.clone(root.committedState);
        root.previewActive = true;
    }

    function patch(path: string, value: var): bool {
        if (!root.previewActive)
            root.beginPreview();
        const candidate = JsonTools.setPath(root.previewState, path, value);
        const errors = Validator.validateSettings(candidate);
        if (errors.length > 0) {
            root.lastError = errors.join("; ");
            return false;
        }
        root.previewState = candidate;
        root.lastError = "";
        return true;
    }

    function apply(): bool {
        const errors = Validator.validateSettings(root.previewState);
        if (errors.length > 0) {
            root.lastError = errors.join("; ");
            return false;
        }
        const payload = JSON.stringify(root.previewState, null, 2) + "\n";
        runtimeSettingsFile.setText(payload);
        root.committedState = JsonTools.clone(root.previewState);
        root.previewActive = false;
        root.lastError = "";
        return true;
    }

    function cancel(): void {
        root.previewState = JsonTools.clone(root.committedState);
        root.previewActive = false;
        root.lastError = "";
    }

    function screenLayout(screenName: string): var {
        const menubar = root.layoutState.menubar || {};
        const screens = menubar.screens || {};
        const base = JsonTools.clone(screens.default || { slots: {} });
        const override = screens[screenName];
        if (!override || !override.slots)
            return base;
        const slots = base.slots || {};
        Object.keys(override.slots).forEach(slotName => slots[slotName] = JsonTools.clone(override.slots[slotName]));
        base.slots = slots;
        return base;
    }

    Component.onCompleted: root.initialize()

    property FileView defaultSettingsFile: FileView {
        path: Quickshell.shellPath("config/defaults/settings.json")
        preload: false
        blockLoading: true
    }

    property FileView defaultLayoutFile: FileView {
        path: Quickshell.shellPath("config/defaults/layout.json")
        preload: false
        blockLoading: true
    }

    property FileView defaultThemeFile: FileView {
        path: Quickshell.shellPath("config/themes/titonium-foundation.json")
        preload: false
        blockLoading: true
    }

    property FileView runtimeSettingsFile: FileView {
        path: root.runtimeSettingsPath
        preload: false
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onSaveFailed: error => Logger.error("config", "settings save failed: " + error)
    }

    property FileView runtimeLayoutFile: FileView {
        path: root.runtimeLayoutPath
        preload: false
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
}
