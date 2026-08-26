pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Core.Runtime
import "ClipboardAccess.js" as ClipboardAccess
import "ClipboardHistory.js" as ClipboardHistory

QtObject {
    id: root
    property var items: []
    property bool available: true
    property string error: ""
    property bool warnedMalformed: false
    readonly property string runtimePath: Quickshell.dataPath("clipboard-history.json")

    function initialize(): void {
        const text = historyFile.text();
        if (!text || text.trim().length === 0) { root.items = []; return; }
        try {
            const document = JSON.parse(text);
            if (!ClipboardHistory.isDocument(document) && !root.warnedMalformed) {
                root.warnedMalformed = true;
                Logger.warn("clipboard", "runtime history is malformed; starting empty");
            }
            root.items = ClipboardHistory.normalizeDocument(document);
        } catch (failure) {
            root.items = [];
            Logger.warn("clipboard", "runtime history contains invalid JSON: " + failure);
        }
    }

    function persist(): void {
        historyFile.setText(JSON.stringify({ schemaVersion: 1, items: root.items }));
    }
    function record(text: string): void {
        if (!text) return;
        root.items = ClipboardHistory.record(root.items, text, Date.now());
        root.persist();
    }
    function remove(id: string): void {
        const next = ClipboardHistory.remove(root.items, id);
        if (next.length === root.items.length) return;
        root.items = next;
        root.persist();
    }
    function clear(): void {
        if (root.items.length === 0) return;
        root.items = [];
        root.persist();
    }
    function copyText(text: string): bool {
        if (!text) return false;
        const result = ClipboardAccess.copy(text, value => Quickshell.clipboardText = value);
        root.available = result.available;
        root.error = result.error;
        return result.accepted;
    }
    function copy(id: string): bool {
        const item = ClipboardHistory.itemForId(root.items, id);
        return item !== null && root.copyText(item.text);
    }
    function observeCurrent(): bool {
        const result = ClipboardAccess.observe(() => Quickshell.clipboardText);
        root.available = result.available;
        root.error = result.error;
        if (result.available && result.text.length > 0) root.record(result.text);
        return result.available;
    }

    property Connections clipboardConnections: Connections {
        target: Quickshell
        function onClipboardTextChanged(): void { root.observeCurrent(); }
    }
    property FileView historyFile: FileView {
        path: root.runtimePath
        preload: false
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onSaveFailed: failure => Logger.error("clipboard", "history save failed: " + failure)
    }
    Component.onCompleted: { root.initialize(); root.observeCurrent(); }
}
