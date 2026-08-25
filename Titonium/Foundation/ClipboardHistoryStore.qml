pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Platform.Clipboard
import "ClipboardHistory.js" as ClipboardHistory

QtObject {
    id: root

    property var items: []
    readonly property string runtimePath: Quickshell.dataPath("clipboard-history.json")
    readonly property bool available: ClipboardAdapter.available
    readonly property string error: ClipboardAdapter.error
    property bool warnedMalformed: false

    function warnMalformed(message: string): void {
        if (root.warnedMalformed)
            return;
        root.warnedMalformed = true;
        Logger.warn("clipboard", message);
    }

    function initialize(): void {
        const text = historyFile.text();
        if (!text || text.trim().length === 0) {
            root.items = [];
            return;
        }
        try {
            const document = JSON.parse(text);
            if (!ClipboardHistory.isDocument(document))
                root.warnMalformed("runtime history document is malformed; starting empty");
            root.items = ClipboardHistory.normalizeDocument(document);
        } catch (error) {
            root.items = [];
            root.warnMalformed("runtime history contains invalid JSON; starting empty: " + error);
        }
    }

    function persist(): void {
        historyFile.setText(JSON.stringify({
            "schemaVersion": 1,
            "items": root.items
        }));
    }

    function record(text: string): void {
        if (typeof text !== "string" || text.length === 0)
            return;
        root.items = ClipboardHistory.record(root.items, text, Date.now());
        root.persist();
    }

    function remove(id: string): void {
        const next = ClipboardHistory.remove(root.items, id);
        if (next.length === root.items.length)
            return;
        root.items = next;
        root.persist();
    }

    function clear(): void {
        if (root.items.length === 0)
            return;
        root.items = [];
        root.persist();
    }

    function copy(id: string): bool {
        const item = ClipboardHistory.itemForId(root.items, id);
        return item !== null && ClipboardAdapter.copy(item.text);
    }

    property Connections clipboardConnections: Connections {
        target: ClipboardAdapter
        function onTextObserved(text: string): void {
            root.record(text);
        }
    }

    property FileView historyFile: FileView {
        path: root.runtimePath
        preload: false
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onSaveFailed: error => Logger.error("clipboard", "history save failed: " + error)
    }

    Component.onCompleted: {
        root.initialize();
        ClipboardAdapter.observeCurrent();
    }
}
