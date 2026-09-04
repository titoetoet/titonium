pragma ComponentBehavior: Bound

import QtQuick
import "CenterDomainRules.js" as CenterDomainRules

QtObject {
    id: root
    property var routes: Object.freeze({})
    property var completedKeys: Object.freeze({})

    function rejected(status: string, reason: string): var {
        return Object.freeze({ accepted: false, status: status, reason: reason,
            closePolicy: "keep" });
    }

    function dispatch(snapshot: var, intent: var): var {
        if (!intent || intent.type !== "invoke-action")
            return root.rejected("rejected", "invalid-intent");
        const actionId = String(intent.actionId || "");
        const contextId = String(intent.contextId || "");
        const actions = snapshot?.capabilities?.actions || [];
        const capability = actions.find(item => item.id === actionId
            && item.contextId === contextId && item.enabled === true);
        if (!capability)
            return root.rejected("stale", "missing-capability");
        const key = String(intent.idempotencyKey || "");
        if (key && root.completedKeys[key])
            return root.completedKeys[key];
        const prefix = actionId.split(".")[0];
        const adapter = root.routes[prefix];
        if (!adapter || !adapter.dispatch)
            return root.rejected("unavailable", "missing-adapter");
        const result = CenterDomainRules.actionResult(
            adapter.dispatch(actionId, contextId, key));
        if (key && result.accepted) {
            const next = Object.assign({}, root.completedKeys);
            next[key] = result;
            root.completedKeys = Object.freeze(next);
        }
        return result;
    }
}
