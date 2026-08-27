pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Core.Runtime
import "DockRules.js" as DockRules

QtObject {
    id: root

    property var state: DockRules.normalizeState(null)
    property bool ready: false
    property bool warnedRuntimeCorruption: false

    readonly property var pinnedIds: root.state.pinnedIds.slice()
    readonly property bool pinnedOpen: root.state.pinnedOpen
    readonly property bool autoHide: root.state.autoHide
    readonly property string runtimePath: Quickshell.dataPath("dock.json")
    readonly property string defaultsPath: Quickshell.configPath("config/defaults/dock.json")

    function parse(file: FileView, label: string, warnOnFailure: bool): var {
        const text = file.text();
        if (!text || text.trim().length === 0)
            return null;
        try {
            return JSON.parse(text);
        } catch (failure) {
            if (warnOnFailure && !root.warnedRuntimeCorruption) {
                root.warnedRuntimeCorruption = true;
                Logger.warn("dock", "runtime dock state contains invalid JSON: " + failure);
            }
            return null;
        }
    }

    function apply(next: var, persist: bool): bool {
        const value = DockRules.normalizeState(next);
        root.state = value;
        if (persist)
            runtimeFile.setText(JSON.stringify(value, null, 2));
        return true;
    }

    function reload(): void {
        const defaults = root.parse(defaultsFile, "shipped dock defaults", false)
            || DockRules.normalizeState(null);
        const runtime = root.parse(runtimeFile, "runtime dock state", true);
        root.state = DockRules.normalizeState(runtime || defaults);
        root.ready = true;
    }

    function togglePin(appId: string): bool {
        const id = (appId || "").trim();
        if (!id)
            return false;
        const key = id.toLocaleLowerCase();
        const nextPinnedIds = root.pinnedIds.slice();
        for (let index = 0; index < nextPinnedIds.length; index++) {
            if (nextPinnedIds[index].toLocaleLowerCase() !== key)
                continue;
            nextPinnedIds.splice(index, 1);
            return root.apply({
                pinnedIds: nextPinnedIds,
                pinnedOpen: root.pinnedOpen,
                autoHide: root.autoHide,
            }, true);
        }
        nextPinnedIds.push(id);
        return root.apply({
            pinnedIds: nextPinnedIds,
            pinnedOpen: root.pinnedOpen,
            autoHide: root.autoHide,
        }, true);
    }

    function setPinnedOpen(value: bool): bool {
        return root.apply({
            pinnedIds: root.pinnedIds,
            pinnedOpen: value === true,
            autoHide: root.autoHide,
        }, true);
    }

    function setAutoHide(value: bool): bool {
        return root.apply({
            pinnedIds: root.pinnedIds,
            pinnedOpen: root.pinnedOpen,
            autoHide: value === true,
        }, true);
    }

    function snapshot(): var {
        return {
            $schema: "titonium.dock/v1",
            schemaVersion: 1,
            pinnedIds: root.pinnedIds,
            pinnedOpen: root.pinnedOpen,
            autoHide: root.autoHide,
        };
    }

    property FileView defaultsFile: FileView {
        path: root.defaultsPath
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
        watchChanges: true
        onFileChanged: root.reload()
        onSaveFailed: failure => Logger.warn("dock", "runtime dock state save failed: " + failure)
    }

    Component.onCompleted: root.reload()
}
