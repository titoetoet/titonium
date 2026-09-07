pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Core.Runtime
import qs.Titonium.Services.Center
import qs.Titonium.Services.Hyprland
import "ClipboardAccess.js" as ClipboardAccess
import "ClipboardHistory.js" as ClipboardHistory
import "ClipboardCenterRules.js" as ClipboardCenterRules

QtObject {
    id: root
    property var items: []
    property bool available: true
    property string error: ""
    property bool warnedMalformed: false
    property bool writing: false
    property bool dirty: false
    property var retiredPaths: []
    property var cleanupPaths: []
    readonly property string ioScript: decodeURIComponent(Qt.resolvedUrl("clipboard_io.py").toString().replace(/^file:\/\//, ""))
    readonly property string imageCachePath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/titonium/clipboard-images"
    property var centerState: ClipboardCenterRules.initialState()
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

    function commitItems(next): void {
        root.retiredPaths = root.retiredPaths.concat(ClipboardHistory.removedImagePaths(root.items, next));
        root.items = next;
        root.persist();
    }
    function persist(): void {
        if (root.writing) { root.dirty = true; return; }
        root.writing = true;
        root.dirty = false;
        historyFile.setText(JSON.stringify({ schemaVersion: 1, items: root.items }));
    }
    function finishSave(success: bool, failure: string): void {
        root.writing = false;
        if (!success) {
            Logger.error("clipboard", "history save failed: " + failure);
            if (root.dirty) root.persist();
            return;
        }
        if (root.dirty) { root.persist(); return; }
        // Keep files referenced by either pending state or a failed persisted snapshot.
        const retained = root.items.filter(item => item.kind === "image").map(item => item.imagePath);
        root.cleanupPaths = root.cleanupPaths.concat(root.retiredPaths.filter(path => retained.indexOf(path) < 0));
        root.retiredPaths = [];
        root.startCleanup();
    }
    function startCleanup(): void {
        if (cleanupProcess.running || root.cleanupPaths.length === 0) return;
        const retained = root.items.filter(item => item.kind === "image").map(item => item.imagePath);
        const paths = root.cleanupPaths.filter(path => retained.indexOf(path) < 0);
        root.cleanupPaths = [];
        if (paths.length === 0) return;
        cleanupProcess.command = ["python3", root.ioScript, "cleanup", root.imageCachePath, JSON.stringify(paths)];
        cleanupProcess.running = true;
    }
    property Process cleanupProcess: Process {
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) Logger.warn("clipboard", "image cache cleanup failed");
            root.startCleanup();
        }
    }
    function record(text: string, sourceApp: string, sourceTitle: string): void {
        if (!text || ClipboardHistory.utf8Bytes(text) > ClipboardHistory.MAX_TEXT_BYTES) return;
        const active = HyprlandService.activeWindow;
        const app = sourceApp || active?.appId || "";
        const title = sourceTitle || active?.title || "";
        root.commitItems(ClipboardHistory.record(root.items, text, Date.now(), app, title));
    }
    function recordImage(imagePath: string, width: int, height: int, bytes: int, md5: string, sourceApp: string, sourceTitle: string): void {
        if (!imagePath) return;
        const active = HyprlandService.activeWindow;
        const app = sourceApp || active?.appId || "";
        const title = sourceTitle || active?.title || "";
        root.commitItems(ClipboardHistory.recordImage(root.items, imagePath, width, height, bytes, md5, Date.now(), app, title));
    }
    function remove(id: string): void {
        const next = ClipboardHistory.remove(root.items, id);
        if (next.length === root.items.length) return;
        root.commitItems(next);
    }
    function clear(): void {
        if (root.items.length === 0) return;
        root.commitItems([]);
    }
    function copyText(text: string): bool {
        if (!text) return false;
        const result = ClipboardAccess.copy(text, value => Quickshell.clipboardText = value);
        root.available = result.available;
        root.error = result.error;
        return result.accepted;
    }
    property Process copyImageProcess: Process {
        command: []
        running: false
        stderr: StdioCollector {}
        onExited: exitCode => root.finishImageCopy(exitCode)
    }
    function finishImageCopy(exitCode: int): void {
        root.available = exitCode === 0;
        root.error = exitCode === 0 ? "" : "clipboard.error.unavailable";
        if (exitCode !== 0) Logger.error("clipboard", "image copy failed");
    }
    function copyImage(path: string): bool {
        if (!path || copyImageProcess.running) return false;
        try {
            copyImageProcess.command = ["python3", root.ioScript, "copy", path];
            copyImageProcess.running = true;
            // Accepted for asynchronous execution; completion updates availability/error.
            return true;
        } catch (failure) {
            root.finishImageCopy(1);
            return false;
        }
    }
    function copy(id: string): bool {
        const item = ClipboardHistory.itemForId(root.items, id);
        if (item === null) return false;
        if (item.kind === "image" && item.imagePath)
            return root.copyImage(item.imagePath);
        return root.copyText(item.text);
    }
    function observeText(text: string): bool {
        if (ClipboardHistory.utf8Bytes(text) > ClipboardHistory.MAX_TEXT_BYTES) return false;
        root.available = true;
        root.error = "";
        const centerResult = ClipboardCenterRules.observe(
            root.centerState, text,
            I18n.tr("menubar.center.clipboard_copied"), Date.now());
        root.centerState = centerResult.next;
        if (centerResult.event !== null)
            CenterAttentionService.publish(centerResult.event);
        if (text)
            root.record(text, "", "");
        return true;
    }

    function observeWatchLine(line: string): bool {
        const text = ClipboardCenterRules.decodeWatchLine(line);
        if (text === null) {
            root.available = false;
            root.error = "clipboard.error.unavailable";
            return false;
        }
        return root.observeText(text);
    }

    function observeImageWatchLine(line: string): void {
        if (!line || line.trim().length === 0) return;
        try {
            const data = JSON.parse(line);
            if (data && data.path && data.width && data.height) {
                root.recordImage(data.path, data.width, data.height, data.bytes || 0, data.md5 || "", "", "");
            }
        } catch (e) {}
    }

    function activate(): void {}

    property Process clipboardWatcher: Process {
        command: ["wl-paste", "--type", "text", "--watch", "python3", root.ioScript, "text"]
        running: false
        stdout: SplitParser {
            onRead: data => root.observeWatchLine(data)
        }
        stderr: StdioCollector {}
        onExited: {
            root.available = false;
            root.error = "clipboard.error.unavailable";
            root.watcherRestart.restart();
        }
    }

    property Process imageWatcher: Process {
        command: ["wl-paste", "--type", "image/png", "--watch", "python3", root.ioScript, "capture", root.imageCachePath]
        running: false
        stdout: SplitParser {
            onRead: data => root.observeImageWatchLine(data)
        }
        stderr: StdioCollector {}
        onExited: {
            root.imageRestart.restart();
        }
    }

    property Timer imageRestart: Timer {
        interval: 2000
        repeat: false
        onTriggered: root.imageWatcher.running = true
    }

    property Timer watcherRestart: Timer {
        interval: 2000
        repeat: false
        onTriggered: root.clipboardWatcher.running = true
    }
    property FileView historyFile: FileView {
        path: root.runtimePath
        preload: false
        blockLoading: true
        printErrors: false
        atomicWrites: true
        onSaved: root.finishSave(true, "")
        onSaveFailed: failure => root.finishSave(false, String(failure))
    }
    Component.onCompleted: {
        root.initialize();
        clipboardWatcher.running = true;
        imageWatcher.running = true;
    }
}
