pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property var entries: ({})

    function zeroRect(): rect {
        return Qt.rect(0, 0, 0, 0);
    }

    function copyRect(value: rect): rect {
        return Qt.rect(value.x, value.y, value.width, value.height);
    }

    function usableRect(value: rect): bool {
        return Number.isFinite(value.x) && Number.isFinite(value.y)
            && Number.isFinite(value.width) && Number.isFinite(value.height)
            && value.width >= 0 && value.height >= 0;
    }

    function publish(ownerId: string, screen: var, body: rect, edge: rect): bool {
        if (!ownerId || !screen?.name || !root.usableRect(body) || !root.usableRect(edge))
            return false;
        const next = Object.assign({}, root.entries);
        next[ownerId] = {
            "screenName": screen.name,
            "body": root.copyRect(body),
            "edge": root.copyRect(edge),
        };
        root.entries = next;
        return true;
    }

    function clear(ownerId: string): bool {
        if (!ownerId || root.entries[ownerId] === undefined)
            return false;
        const next = Object.assign({}, root.entries);
        delete next[ownerId];
        root.entries = next;
        return true;
    }

    function regionsFor(screen: var): var {
        const result = {
            "body": root.zeroRect(),
            "edge": root.zeroRect(),
        };
        if (!screen?.name)
            return result;
        for (const ownerId of Object.keys(root.entries)) {
            const entry = root.entries[ownerId];
            if (entry?.screenName !== screen.name)
                continue;
            result.body = root.copyRect(entry.body);
            result.edge = root.copyRect(entry.edge);
            break;
        }
        return result;
    }
}
