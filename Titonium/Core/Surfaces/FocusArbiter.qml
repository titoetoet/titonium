pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.Titonium.Core.Runtime
import "FocusArbiterRules.js" as FocusArbiterRules

QtObject {
    id: root

    property var state: FocusArbiterRules.initial()
    property int scheduledGeneration: -1
    readonly property string owner: root.state.owner
    readonly property string pendingOwner: root.state.pendingOwner
    readonly property string phase: root.state.phase
    readonly property int generation: root.state.generation

    function request(ownerId: string, active: bool): void {
        const next = active
            ? FocusArbiterRules.request(root.state, ownerId)
            : FocusArbiterRules.withdraw(root.state, ownerId);
        root.apply(next);
    }

    function withdraw(ownerId: string): void {
        root.apply(FocusArbiterRules.withdraw(root.state, ownerId));
    }

    function granted(ownerId: string): bool {
        return root.owner === ownerId && root.phase === "owned";
    }

    function apply(next: var): void {
        if (next === root.state)
            return;
        const previous = root.state;
        if (next.violation)
            Logger.warn("focus", next.violation);
        const displaced = previous.owner || previous.pendingOwner;
        if (next.pendingOwner && displaced && displaced !== next.pendingOwner)
            Logger.info("focus", "replacing " + displaced + " with " + next.pendingOwner);
        root.state = next;
        if (next.shouldSchedule && root.scheduledGeneration !== next.generation)
            root.scheduleGrant(next.generation);
    }

    function scheduleGrant(generation: int): void {
        root.scheduledGeneration = generation;
        Qt.callLater(() => {
            if (root.scheduledGeneration === generation)
                root.scheduledGeneration = -1;
            const next = FocusArbiterRules.grantPending(root.state, generation);
            if (next === root.state) {
                Logger.info("focus", "rejected focus grant generation " + generation);
                return;
            }
            root.apply(next);
        });
    }
}
