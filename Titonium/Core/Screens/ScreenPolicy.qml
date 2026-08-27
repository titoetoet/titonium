pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "ScreenPolicy.js" as Rules

QtObject {
    readonly property string targetScreenName: "DP-1"
    readonly property var screens: Rules.eligibleScreens(Quickshell.screens, targetScreenName)

    function acceptsScreen(screen: var): bool {
        return Rules.acceptsScreen(screen, targetScreenName);
    }
}
