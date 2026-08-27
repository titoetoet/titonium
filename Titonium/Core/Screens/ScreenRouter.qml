pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime

QtObject {
    id: root

    property var activeScreen: null

    function setActiveScreen(screen: var): void {
        root.activeScreen = screen;
    }

    function preferredScreen(): var {
        if (ScreenPolicy.acceptsScreen(root.activeScreen))
            return root.activeScreen;
        return ScreenPolicy.screens.length > 0 ? ScreenPolicy.screens[0] : null;
    }

    function screenForName(screenName: string): var {
        if (screenName && screenName.length > 0) {
            for (let index = 0; index < ScreenPolicy.screens.length; index++) {
                if (ScreenPolicy.screens[index].name === screenName)
                    return ScreenPolicy.screens[index];
            }
            Logger.warn("screen", "unknown screen " + screenName + "; using preferred screen");
        }
        return root.preferredScreen();
    }
}
