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

    function screenForName(screenName: string): var {
        if (screenName && screenName.length > 0) {
            for (let index = 0; index < Quickshell.screens.length; index++) {
                if (Quickshell.screens[index].name === screenName)
                    return Quickshell.screens[index];
            }
            Logger.warn("screen", "unknown screen " + screenName + "; using preferred screen");
        }
        return root.preferredScreen();
    }
}
