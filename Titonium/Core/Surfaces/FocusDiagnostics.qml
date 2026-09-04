pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "FocusOwnershipRules.js" as FocusOwnershipRules

QtObject {
    id: root
    property var state: FocusOwnershipRules.initial()
    property string holderOwnerId: ""
    property string holderLease: ""

    function observe(ownerId: string, lease: string, active: bool, metadata: var): void {
        const logicalOwnerId = String(ownerId || "").trim();
        const requesterLease = String(lease || "").trim();
        if (!requesterLease && active !== true)
            return;
        const now = Date.now();
        if (!requesterLease) {
            Logger.warn("focus", "missing-focus-lease " + JSON.stringify(metadata || {}));
            return;
        }
        if (active !== true && (root.holderOwnerId !== logicalOwnerId
                || root.holderLease !== requesterLease))
            return;
        const next = FocusOwnershipRules.transition(root.state, logicalOwnerId,
            active, now, requesterLease);
        if (next.violation)
            Logger.warn("focus", next.violation + " " + JSON.stringify(metadata || {}));
        else if (next.owner !== root.state.owner)
            Logger.info("focus", (active ? "acquired " : "released ") + logicalOwnerId
                + " " + JSON.stringify(metadata || {}));
        root.state = next;
        if (active === true && !next.violation) {
            root.holderOwnerId = logicalOwnerId;
            root.holderLease = requesterLease;
        } else if (active !== true) {
            root.holderOwnerId = "";
            root.holderLease = "";
        }
    }
}
