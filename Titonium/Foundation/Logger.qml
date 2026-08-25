pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    function info(scope: string, message: string): void {
        console.info("[titonium][" + scope + "] " + message);
    }

    function warn(scope: string, message: string): void {
        console.warn("[titonium][" + scope + "] " + message);
    }

    function error(scope: string, message: string): void {
        console.error("[titonium][" + scope + "] " + message);
    }
}

