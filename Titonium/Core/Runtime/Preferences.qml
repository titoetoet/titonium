pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "PreferencesValidator.js" as Validator

QtObject {
    id: root

    property var settings: Validator.project(null, { "locale": "vi" })
    property bool ready: false

    readonly property string locale: root.settings.locale || "vi"
    readonly property bool reducedMotion: root.settings.accessibility?.reducedMotion === true
    readonly property var hiddenApplicationIds: root.settings.applications?.hiddenIds || []
    readonly property var spotlight: root.settings.modules?.spotlight || ({})
    readonly property bool use24Hour: root.settings.modules?.clock?.use24Hour !== false
    readonly property bool allowAudioAmplification:
        root.settings.modules?.audio?.allowAmplification === true

    function parse(file: FileView, label: string): var {
        const text = file.text();
        if (!text || text.trim().length === 0)
            return null;
        try {
            return JSON.parse(text);
        } catch (error) {
            Logger.warn("preferences", label + " contains invalid JSON: " + error);
            return null;
        }
    }

    function reload(): void {
        const defaults = root.parse(defaultsFile, "shipped settings") || { "locale": "vi" };
        const runtime = root.parse(runtimeFile, "runtime settings");
        root.settings = Validator.project(runtime || defaults, defaults);
        root.ready = true;
        Logger.info("preferences", "protected preferences loaded");
    }

    Component.onCompleted: root.reload()

    property FileView defaultsFile: FileView {
        path: Quickshell.shellPath("config/defaults/settings.json")
        preload: false
        blockLoading: true
    }

    property FileView runtimeFile: FileView {
        path: Quickshell.dataPath("settings.json")
        preload: false
        blockLoading: true
        printErrors: false
    }
}
