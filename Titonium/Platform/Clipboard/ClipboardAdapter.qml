pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    id: root

    signal textObserved(string text)

    function observe(text: string): void {
        if (typeof text === "string" && text.length > 0)
            root.textObserved(text);
    }

    function observeCurrent(): void {
        root.observe(Quickshell.clipboardText);
    }

    function copy(text: string): bool {
        if (typeof text !== "string" || text.length === 0)
            return false;
        Quickshell.clipboardText = text;
        return true;
    }

    property Connections clipboardConnections: Connections {
        target: Quickshell
        function onClipboardTextChanged(): void {
            root.observe(Quickshell.clipboardText);
        }
    }

    Component.onCompleted: root.observeCurrent()
}
