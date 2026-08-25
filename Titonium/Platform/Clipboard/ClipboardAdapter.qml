pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "ClipboardAccess.js" as ClipboardAccess

QtObject {
    id: root

    property bool available: true
    property string error: ""

    signal textObserved(string text)

    function observe(text: string): void {
        if (typeof text === "string" && text.length > 0)
            root.textObserved(text);
    }

    function observeCurrent(): bool {
        const result = ClipboardAccess.observe(() => Quickshell.clipboardText);
        root.available = result.available;
        root.error = result.error;
        if (result.available)
            root.observe(result.text);
        return result.available;
    }

    function copy(text: string): bool {
        if (typeof text !== "string" || text.length === 0)
            return false;
        const result = ClipboardAccess.copy(text, value => {
            Quickshell.clipboardText = value;
        });
        root.available = result.available;
        root.error = result.error;
        return result.accepted;
    }

    property Connections clipboardConnections: Connections {
        target: Quickshell
        function onClipboardTextChanged(): void {
            root.observeCurrent();
        }
    }
}
