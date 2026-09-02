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

    function persist(): void {
        historyFile.setText(JSON.stringify({ schemaVersion: 1, items: root.items }));
    }
    function record(text: string, sourceApp: string, sourceTitle: string): void {
        if (!text) return;
        const active = HyprlandService.activeWindow;
        const app = sourceApp || active?.appId || "";
        const title = sourceTitle || active?.title || "";
        root.items = ClipboardHistory.record(root.items, text, Date.now(), app, title);
        root.persist();
    }
    function recordImage(imagePath: string, width: int, height: int, bytes: int, md5: string, sourceApp: string, sourceTitle: string): void {
        if (!imagePath) return;
        const active = HyprlandService.activeWindow;
        const app = sourceApp || active?.appId || "";
        const title = sourceTitle || active?.title || "";
        root.items = ClipboardHistory.recordImage(root.items, imagePath, width, height, bytes, md5, Date.now(), app, title);
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
    property Process copyImageProcess: Process {
        command: []
        running: false
    }
    function copyImage(path: string): bool {
        if (!path) return false;
        copyImageProcess.command = ["sh", "-c", "wl-copy -t image/png < \"$1\"", "--", path];
        copyImageProcess.running = true;
        return true;
    }
    function copy(id: string): bool {
        const item = ClipboardHistory.itemForId(root.items, id);
        if (item === null) return false;
        if (item.kind === "image" && item.imagePath)
            return root.copyImage(item.imagePath);
        return root.copyText(item.text);
    }
    function observeText(text: string): bool {
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
        command: ["wl-paste", "--type", "text", "--watch", "python3", "-c",
            "import json, sys; print(json.dumps(sys.stdin.read(), ensure_ascii=False))"]
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
        command: ["wl-paste", "--type", "image/png", "--watch", "python3", "-c",
            "import sys, os, hashlib, struct, json, subprocess\n"
            + "cache_dir = os.path.expanduser('~/.local/share/titonium/clipboard-images')\n"
            + "os.makedirs(cache_dir, exist_ok=True)\n"
            + "p = subprocess.run(['wl-paste', '--type', 'image/png'], capture_output=True)\n"
            + "if p.returncode == 0 and len(p.stdout) > 24 and p.stdout[:8] == b'\\x89PNG\\r\\n\\x1a\\n':\n"
            + "    w, h = struct.unpack('>II', p.stdout[16:24])\n"
            + "    md5 = hashlib.md5(p.stdout).hexdigest()\n"
            + "    out_path = os.path.join(cache_dir, f'{md5}.png')\n"
            + "    with open(out_path, 'wb') as f: f.write(p.stdout)\n"
            + "    print(json.dumps({'path': out_path, 'width': w, 'height': h, 'bytes': len(p.stdout), 'md5': md5}))\n"
        ]
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
        onSaveFailed: failure => Logger.error("clipboard", "history save failed: " + failure)
    }
    Component.onCompleted: {
        root.initialize();
        clipboardWatcher.running = true;
        imageWatcher.running = true;
    }
}
