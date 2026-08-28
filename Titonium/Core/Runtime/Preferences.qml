pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "PreferencesValidator.js" as Validator

QtObject {
    id: root

    property var shippedDefaults: Validator.project(null, {}, null)
    property var committedState: Validator.clone(root.shippedDefaults)
    property var previewState: Validator.clone(root.shippedDefaults)
    property var pendingApplyState: null
    property bool previewActive: false
    property bool savePending: false
    property bool pendingApplyWrite: false
    property int pendingRuntimeWrites: 0
    property string lastError: ""
    property bool ready: false
    property bool warnedRuntimeCorruption: false

    readonly property var effectiveState: root.previewActive
        ? root.previewState : root.committedState
    readonly property var settings: root.effectiveState
    readonly property bool dirty: root.previewActive
        && !Validator.same(root.previewState, root.committedState)

    readonly property string locale: root.effectiveState.locale || "vi"
    readonly property bool reducedMotion:
        root.effectiveState.accessibility?.reducedMotion === true
    readonly property var hiddenApplicationIds:
        root.effectiveState.applications?.hiddenIds || []
    readonly property var spotlight: root.effectiveState.modules?.spotlight || ({})
    readonly property var bar: root.effectiveState.modules?.bar || ({})
    readonly property var dock: root.effectiveState.modules?.dock || ({})
    readonly property var notifications:
        root.effectiveState.modules?.notifications || ({})
    readonly property bool use24Hour:
        root.effectiveState.modules?.clock?.use24Hour !== false
    readonly property bool allowAudioAmplification:
        root.effectiveState.modules?.audio?.allowAmplification === true
    readonly property string runtimePath: Quickshell.dataPath("settings.json")

    function parse(file: FileView, label: string, warnOnFailure: bool): var {
        const text = file.text();
        if (!text || text.trim().length === 0)
            return null;
        try {
            return JSON.parse(text);
        } catch (error) {
            if (warnOnFailure && !root.warnedRuntimeCorruption) {
                root.warnedRuntimeCorruption = true;
                Logger.warn("preferences", label + " contains invalid JSON: " + error);
            }
            return null;
        }
    }

    function reload(): void {
        if (root.previewActive || root.pendingRuntimeWrites > 0)
            return;
        const defaults = root.parse(defaultsFile, "shipped settings", true)
            || Validator.project(null, {}, null);
        const runtime = root.parse(runtimeFile, "runtime settings", true);
        const legacyDock = root.parse(legacyDockFile, "legacy Dock state", true);
        root.shippedDefaults = Validator.project(null, defaults, null);
        root.committedState = Validator.project(runtime, defaults, legacyDock);
        root.previewState = Validator.clone(root.committedState);
        root.pendingApplyState = null;
        root.previewActive = false;
        root.savePending = false;
        root.pendingApplyWrite = false;
        root.lastError = "";
        root.ready = true;
        Logger.info("preferences", "settings v7 preferences loaded");
    }

    function beginPreview(): bool {
        if (root.savePending)
            return false;
        if (!root.previewActive) {
            root.previewState = Validator.clone(root.committedState);
            root.previewActive = true;
            root.lastError = "";
        }
        return true;
    }

    function patch(path: string, value: var): bool {
        if (root.savePending || (!root.previewActive && !root.beginPreview()))
            return false;
        try {
            const candidate = Validator.setPath(root.previewState, path, value);
            root.previewState = Validator.project(candidate, root.shippedDefaults, null);
            root.lastError = "";
            return true;
        } catch (failure) {
            root.lastError = String(failure);
            return false;
        }
    }

    function beginRuntimeWrite(): void {
        root.pendingRuntimeWrites += 1;
    }

    function finishRuntimeWrite(success: bool, failure: string): void {
        root.pendingRuntimeWrites = Math.max(0, root.pendingRuntimeWrites - 1);
        if (root.pendingApplyWrite) {
            if (success) {
                root.committedState = Validator.clone(root.pendingApplyState);
                root.previewState = Validator.clone(root.committedState);
                root.lastError = "";
            } else {
                root.lastError = failure || "Unable to save settings";
            }
            root.pendingApplyState = null;
            root.pendingApplyWrite = false;
            root.savePending = false;
        } else if (!success) {
            root.lastError = failure || "Unable to save settings";
        }
    }

    function apply(): bool {
        if (!root.previewActive || !root.dirty || root.savePending
                || root.pendingRuntimeWrites > 0)
            return false;
        root.pendingApplyState = Validator.clone(root.previewState);
        root.pendingApplyWrite = true;
        root.savePending = true;
        root.lastError = "";
        root.beginRuntimeWrite();
        runtimeFile.setText(JSON.stringify(root.pendingApplyState, null, 2));
        return true;
    }

    function cancel(): void {
        if (root.savePending)
            return;
        root.previewState = Validator.clone(root.committedState);
        root.pendingApplyState = null;
        root.previewActive = false;
        root.pendingApplyWrite = false;
        root.lastError = "";
    }

    function restoreAppearance(): bool {
        if (!root.beginPreview())
            return false;
        return root.patch("appearance", root.shippedDefaults.appearance);
    }

    function commitPatch(path: string, value: var): bool {
        if (root.previewActive || root.savePending)
            return false;
        try {
            const candidate = Validator.setPath(root.committedState, path, value);
            root.committedState = Validator.project(candidate, root.shippedDefaults, null);
            root.previewState = Validator.clone(root.committedState);
            root.lastError = "";
            root.beginRuntimeWrite();
            runtimeFile.setText(JSON.stringify(root.committedState, null, 2));
            return true;
        } catch (failure) {
            root.lastError = String(failure);
            return false;
        }
    }

    Component.onCompleted: root.reload()

    property FileView defaultsFile: FileView {
        path: Quickshell.shellPath("config/defaults/settings.json")
        preload: false
        blockLoading: true
    }

    property FileView legacyDockFile: FileView {
        path: Quickshell.dataPath("dock.json")
        preload: false
        blockLoading: true
        printErrors: false
    }

    property FileView runtimeFile: FileView {
        path: root.runtimePath
        preload: false
        blockLoading: true
        printErrors: false
        atomicWrites: true
        watchChanges: !root.previewActive && root.pendingRuntimeWrites === 0
        onFileChanged: root.reload()
        onSaved: root.finishRuntimeWrite(true, "")
        onSaveFailed: failure => root.finishRuntimeWrite(false, String(failure))
    }
}
