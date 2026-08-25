pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

QtObject {
    readonly property string loginName: Quickshell.env("USER") || "user"
}
