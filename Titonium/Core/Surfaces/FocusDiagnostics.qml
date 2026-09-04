pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "FocusOwnershipRules.js" as FocusOwnershipRules

QtObject {
    id: root
    property var state: FocusOwnershipRules.initial()

    function observe(ownerId: string, active: bool, metadata: var): void {
        const next = FocusOwnershipRules.transition(root.state, ownerId, active, Date.now());
        if (next.violation)
            Logger.warn("focus", next.violation + " " + JSON.stringify(metadata || {}));
        else if (next.owner !== root.state.owner)
            Logger.info("focus", (active ? "acquired " : "released ") + ownerId
                + " " + JSON.stringify(metadata || {}));
        root.state = next;
    }
}
