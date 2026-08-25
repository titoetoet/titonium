pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    id: root

    property var activeScreen: null

    function setActiveScreen(screen: var): void {
        root.activeScreen = screen;
    }

    function preferredScreen(): var {
        if (root.activeScreen)
            return root.activeScreen;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }
}

