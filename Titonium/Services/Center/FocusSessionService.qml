pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

QtObject {
    id: root
    property var session: null
    signal finished()
    function start(durationSeconds: int): bool {
        if (durationSeconds <= 0 || durationSeconds > 86400)
            return false;
        const now = Date.now();
        root.session = Object.freeze({ startedAt: now,
            durationMs: durationSeconds * 1000, deadline: now + durationSeconds * 1000 });
        expiry.interval = durationSeconds * 1000;
        expiry.restart();
        return true;
    }
    function cancel(): void { expiry.stop(); root.session = null; }
    property Timer expiry: Timer {
        id: expiry
        onTriggered: { root.session = null; root.finished(); }
    }
}
