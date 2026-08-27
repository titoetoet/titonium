pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property bool pinned: true

    function togglePinned(): bool {
        root.pinned = !root.pinned;
        return root.pinned;
    }
}
