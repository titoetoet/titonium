pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    function copy(text: string): bool {
        if (typeof text !== "string" || text.length === 0)
            return false;
        Quickshell.clipboardText = text;
        return true;
    }
}
