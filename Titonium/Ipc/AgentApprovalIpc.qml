pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.Titonium.Services.AgentApproval

QtObject {
    property IpcHandler handler: IpcHandler {
        target: "agentApproval"
        function state(): string { return AgentApprovalService.snapshot(); }
        function decide(requestId: string, decision: string): bool {
            return AgentApprovalService.decide(requestId, decision);
        }
        function activate(): bool {
            AgentApprovalService.activate();
            return true;
        }
        function clearGrants(): bool {
            AgentApprovalService.clearSessionGrants();
            return true;
        }
    }
}
