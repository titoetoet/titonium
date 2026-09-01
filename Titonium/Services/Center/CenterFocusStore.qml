pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Titonium.Core.Runtime
import "CenterFocusRules.js" as CenterFocusRules

QtObject {
    id: root

    property string markdown: ""
    property string prompts: ""
    property double focusModifiedAt: 0
    property string selectedText: ""
    property bool storeReady: false
    property bool launchInProgress: false
    property bool saveInProgress: false
    property bool awaitingStarterSave: false
    property bool statRefreshPending: false
    property string pendingFocusText: ""
    property string focusBeforeSave: ""
    property string directoryIntent: ""

    readonly property string centerPath: Quickshell.dataPath("center/")
    readonly property string focusPath: Quickshell.dataPath("center/daily-focus.md")
    readonly property string promptsPath: Quickshell.dataPath("center/focus-prompts.txt")
    readonly property string text: root.selectedText
        || I18n.tr("menubar.center.focus_fallback")
    readonly property bool ready: root.storeReady

    function readText(file: FileView): string {
        const value = file.text();
        return typeof value === "string" ? value : "";
    }

    function recompute(): void {
        root.selectedText = CenterFocusRules.select({
            markdown: root.markdown,
            modifiedAt: root.focusModifiedAt,
            prompts: root.prompts
        }, new Date());
    }

    function requestStat(): void {
        if (statProcess.running) {
            root.statRefreshPending = true;
            return;
        }
        statProcess.running = true;
    }

    function refreshFocus(): void {
        root.markdown = root.readText(focusFile);
        root.storeReady = false;
        root.requestStat();
    }

    function refreshPrompts(): void {
        root.prompts = root.readText(promptsFile);
        root.recompute();
    }

    function scheduleMidnight(): void {
        midnightTimer.stop();
        const now = new Date();
        const next = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
        midnightTimer.interval = Math.max(1, next.getTime() - now.getTime());
        midnightTimer.start();
    }

    function initialize(): void {
        root.markdown = root.readText(focusFile);
        root.prompts = root.readText(promptsFile);
        root.requestStat();
        root.scheduleMidnight();
    }

    function publishLaunchFailure(): void {
        root.launchInProgress = false;
        root.awaitingStarterSave = false;
        root.directoryIntent = "";
        CenterAttentionService.publish({
            id: "center:scratchpad-open",
            source: "center",
            kind: "error",
            title: I18n.tr("menubar.center.scratchpad_open_failed"),
            icon: "error",
            createdAt: Date.now()
        });
    }

    function publishSaveFailure(): void {
        root.markdown = root.focusBeforeSave;
        root.recompute();
        root.saveInProgress = false;
        root.pendingFocusText = "";
        root.focusBeforeSave = "";
        root.directoryIntent = "";
        CenterAttentionService.publish({
            id: "center:focus-save",
            source: "center",
            kind: "error",
            title: I18n.tr("menubar.center.focus_save_failed"),
            icon: "error",
            createdAt: Date.now()
        });
    }

    function startOpen(): void {
        xdgOpenProcess.running = true;
    }

    function continueAfterDirectory(): void {
        const intent = root.directoryIntent;
        root.directoryIntent = "";
        if (intent === "save") {
            root.focusBeforeSave = root.markdown;
            root.markdown = root.pendingFocusText.length > 0
                ? root.pendingFocusText + "\n" : "";
            root.focusModifiedAt = Date.now();
            root.recompute();
            focusFile.setText(root.markdown);
            return;
        }

        const current = root.readText(focusFile);
        root.markdown = current;
        if (current.trim().length > 0) {
            root.startOpen();
            return;
        }

        root.awaitingStarterSave = true;
        focusFile.setText(I18n.tr("menubar.center.focus_fallback") + "\n");
    }

    function openScratchpad(): bool {
        if (root.launchInProgress || root.saveInProgress || mkdirProcess.running)
            return false;
        root.launchInProgress = true;
        root.directoryIntent = "open";
        mkdirProcess.running = true;
        return true;
    }

    function saveToday(value: string): bool {
        if (root.launchInProgress || root.saveInProgress || mkdirProcess.running)
            return false;
        root.pendingFocusText = CenterFocusRules.sanitizeInput(value);
        root.saveInProgress = true;
        root.directoryIntent = "save";
        mkdirProcess.running = true;
        return true;
    }

    function snapshot(): string {
        return JSON.stringify({
            ready: root.ready,
            text: root.text,
            focusPath: root.focusPath,
            promptsPath: root.promptsPath,
            launching: root.launchInProgress,
            saving: root.saveInProgress
        });
    }

    Component.onCompleted: root.initialize()

    property FileView focusFile: FileView {
        path: root.focusPath
        preload: false
        blockLoading: true
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: root.refreshFocus()
        onSaved: {
            if (root.saveInProgress) {
                root.saveInProgress = false;
                root.pendingFocusText = "";
                root.focusBeforeSave = "";
                root.requestStat();
            }
            if (!root.awaitingStarterSave)
                return;
            root.awaitingStarterSave = false;
            root.startOpen();
        }
        onSaveFailed: {
            if (root.saveInProgress) {
                root.publishSaveFailure();
                return;
            }
            if (root.awaitingStarterSave)
                root.publishLaunchFailure();
        }
    }

    property FileView promptsFile: FileView {
        path: root.promptsPath
        preload: false
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: root.refreshPrompts()
    }

    property Process statProcess: Process {
        command: ["stat", "-c", "%Y", root.focusPath]
        stdout: StdioCollector {
            id: statOutput
        }
        stderr: StdioCollector {}
        onExited: exitCode => {
            const epochSeconds = exitCode === 0 ? Number(statOutput.text.trim()) : 0;
            root.focusModifiedAt = Number.isFinite(epochSeconds) ? epochSeconds * 1000 : 0;
            root.storeReady = true;
            root.recompute();
            if (root.statRefreshPending) {
                root.statRefreshPending = false;
                root.requestStat();
            }
        }
    }

    property Process mkdirProcess: Process {
        command: ["mkdir", "-p", root.centerPath]
        onExited: exitCode => {
            if (exitCode === 0)
                root.continueAfterDirectory();
            else if (root.directoryIntent === "save")
                root.publishSaveFailure();
            else
                root.publishLaunchFailure();
        }
    }

    property Process xdgOpenProcess: Process {
        command: ["xdg-open", root.focusPath]
        onExited: exitCode => {
            if (exitCode === 0)
                root.launchInProgress = false;
            else
                root.publishLaunchFailure();
        }
    }

    property Timer midnightTimer: Timer {
        repeat: false
        onTriggered: {
            root.recompute();
            root.scheduleMidnight();
        }
    }
}
