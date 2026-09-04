pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Titonium.Core.Runtime
import qs.Titonium.Core.Screens
import qs.Titonium.Services.Center
import qs.Titonium.Services.Hyprland
import "ApprovalRules.js" as ApprovalRules

QtObject {
    id: root

    property var pending: Object.freeze([])
    property var clients: ({})
    property var sessionGrants: ({})
    property var sessionGrantOrder: Object.freeze([])
    property string popupScreenName: ""
    readonly property bool hasPending: root.pending.length > 0
    readonly property var current: root.hasPending ? root.pending[0] : null
    readonly property bool currentIsFileChange: ApprovalRules.isFileChange(root.current)
    readonly property string runtimeDirectory: String(Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
    readonly property string socketPath: String(Quickshell.env("TITONIUM_AGENT_APPROVAL_SOCKET")
        || (root.runtimeDirectory + "/titonium-agent-approval.sock"))

    readonly property string grantsFilePath: root.runtimeDirectory + "/titonium-agent-approval-grants.json"

    function activate(): void {
        server.active = false;
        server.active = true;
    }

    function loadPersistedGrants(): void {
        try {
            const raw = grantsFile.text();
            if (!raw || !raw.trim())
                return;
            const data = JSON.parse(raw);
            if (data && typeof data.grants === "object" && Array.isArray(data.order)) {
                root.sessionGrants = data.grants;
                root.sessionGrantOrder = Object.freeze(data.order);
            }
        } catch (_) {}
    }

    function persistGrants(): void {
        try {
            const data = JSON.stringify({
                grants: root.sessionGrants,
                order: root.sessionGrantOrder
            }, null, 2);
            grantsFile.setText(data);
        } catch (_) {}
    }

    function screenExists(screenName: string): bool {
        if (!screenName)
            return false;
        const screens = Quickshell.screens || [];
        for (let index = 0; index < screens.length; index++) {
            if (screens[index]?.name === screenName)
                return true;
        }
        return false;
    }

    function screenNameFromMonitor(monitorValue: var): string {
        if (monitorValue === undefined || monitorValue === null || String(monitorValue).length === 0)
            return "";
        const str = String(monitorValue);
        if (root.screenExists(str))
            return str;
        const monitors = Hyprland.monitors?.values || [];
        for (let i = 0; i < monitors.length; i++) {
            const m = monitors[i];
            if (String(m?.id) === str || String(m?.name) === str) {
                if (root.screenExists(m?.name || ""))
                    return m.name;
            }
        }
        return "";
    }

    function sourceWindowScreenName(source: string): string {
        const normalizedSource = String(source || "").toLowerCase();
        const needles = normalizedSource === "antigravity"
            ? ["antigravity-ide", "antigravity ide"]
            : normalizedSource === "chatgpt"
                ? ["chatgpt"]
                : [];
        const extraNeedles = normalizedSource === "antigravity" ? ["antigravity"] : [];
        const allNeedles = needles.concat(extraNeedles);
        const windows = HyprlandService.windows || [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            const identity = (String(window?.appId || "") + " "
                + String(window?.title || "") + " "
                + String(window?.ipcClass || "") + " "
                + String(window?.initialClass || "")).toLowerCase();
            for (let needleIndex = 0; needleIndex < allNeedles.length; needleIndex++) {
                if (identity.includes(allNeedles[needleIndex])) {
                    const resolved = root.screenNameFromMonitor(window?.monitorName);
                    if (resolved)
                        return resolved;
                }
            }
        }
        return "";
    }

    function popupScreenNameFor(source: string): string {
        const sourceScreenName = root.sourceWindowScreenName(source);
        if (sourceScreenName)
            return sourceScreenName;

        // Direct Hyprland state is only the fallback when the source app has
        // no visible window (closed, minimized, or not projected yet).
        const focusedName = Hyprland.focusedMonitor?.name || "";
        if (root.screenExists(focusedName))
            return focusedName;
        return ScreenPolicy.screens.length > 0 ? ScreenPolicy.screens[0].name : "";
    }

    function updatePopupScreenAfterRemoval(): void {
        if (root.pending.length === 0)
            root.popupScreenName = "";
    }

    function syncCenterAttention(): void {
        if (root.pending.length === 0) {
            CenterAttentionService.clear("agent:approval");
            return;
        }
        const descriptor = root.pending[0];
        CenterAttentionService.publish({
            id: "agent:approval",
            deduplicationKey: "agent:approval",
            source: "agent",
            kind: "approval_required",
            title: I18n.tr("agent_approval.center.waiting", {
                "source": descriptor.title || "AI"
            }),
            icon: "smart_toy"
        });
    }

    function receive(client: var, line: string): void {
        try {
            const payload = JSON.parse(line);
            const descriptor = ApprovalRules.normalize(payload);
            if (!descriptor.requestId || root.clients[descriptor.requestId] !== undefined
                    || root.pending.length >= 32) {
                client.write(JSON.stringify({ "decision": "deny" }) + "\n");
                client.flush();
                client.connected = false;
                return;
            }
            const grantKey = ApprovalRules.sessionGrantKey(descriptor);
            const convKey = descriptor.conversationId ? ("conv:" + descriptor.conversationId) : "";
            const keys = ApprovalRules.sessionKeys ? ApprovalRules.sessionKeys(descriptor) : [];
            let isGranted = (grantKey && root.sessionGrants[grantKey] === true)
                || (convKey && root.sessionGrants[convKey] === true);
            if (!isGranted && keys.length > 0) {
                for (let i = 0; i < keys.length; i++) {
                    if (root.sessionGrants[keys[i]] === true) {
                        isGranted = true;
                        break;
                    }
                }
            }
            if (isGranted && !ApprovalRules.requiresExplicitApproval(descriptor)) {
                client.write(JSON.stringify(
                    ApprovalRules.decisionPayload(descriptor.source, "allow_session", descriptor)) + "\n");
                client.flush();
                client.connected = false;
                return;
            }
            const nextClients = Object.assign({}, root.clients);
            nextClients[descriptor.requestId] = client;
            root.clients = nextClients;
            if (root.pending.length === 0)
                root.popupScreenName = root.popupScreenNameFor(descriptor.source);
            root.pending = Object.freeze(root.pending.concat([descriptor]));
            root.syncCenterAttention();
        } catch (error) {
            client.write(JSON.stringify({ "decision": "deny" }) + "\n");
            client.flush();
            client.connected = false;
        }
    }

    function disconnected(client: var): void {
        const requestId = Object.keys(root.clients).find(id => root.clients[id] === client);
        if (!requestId)
            return;
        const nextClients = Object.assign({}, root.clients);
        delete nextClients[requestId];
        root.clients = nextClients;
        root.pending = Object.freeze(root.pending.filter(item => item.requestId !== requestId));
        root.updatePopupScreenAfterRemoval();
        root.syncCenterAttention();
    }

    function decide(requestId: string, decision: string): bool {
        const descriptor = root.pending.find(item => item.requestId === requestId);
        const client = root.clients[requestId];
        if (!descriptor || !client)
            return false;
        if (decision === "allow_session")
            root.rememberSessionGrant(descriptor);
        try {
            client.write(JSON.stringify(ApprovalRules.decisionPayload(descriptor.source, decision, descriptor)) + "\n");
            client.flush();
            client.connected = false;
        } catch (e) {
            console.warn("[titonium][agentApproval] write failed:", e);
        }
        const nextClients = Object.assign({}, root.clients);
        delete nextClients[requestId];
        root.clients = nextClients;
        root.pending = Object.freeze(root.pending.filter(item => item.requestId !== requestId));
        root.updatePopupScreenAfterRemoval();
        root.syncCenterAttention();
        return true;
    }

    function rememberSessionGrant(descriptor: var): bool {
        const grantKey = ApprovalRules.sessionGrantKey(descriptor);
        const convKey = descriptor.conversationId ? ("conv:" + descriptor.conversationId) : "";
        const keys = ApprovalRules.sessionKeys ? ApprovalRules.sessionKeys(descriptor) : [];
        if ((!grantKey && !convKey && keys.length === 0) || ApprovalRules.requiresExplicitApproval(descriptor))
            return false;
        const nextGrants = Object.assign({}, root.sessionGrants);
        let nextOrder = root.sessionGrantOrder.slice();
        if (grantKey) {
            nextOrder = nextOrder.filter(key => key !== grantKey).concat([grantKey]);
            nextGrants[grantKey] = true;
        }
        if (convKey) {
            nextOrder = nextOrder.filter(key => key !== convKey).concat([convKey]);
            nextGrants[convKey] = true;
        }
        for (let i = 0; i < keys.length; i++) {
            const k = keys[i];
            nextOrder = nextOrder.filter(key => key !== k).concat([k]);
            nextGrants[k] = true;
        }
        while (nextOrder.length > 128)
            delete nextGrants[nextOrder.shift()];
        root.sessionGrants = nextGrants;
        root.sessionGrantOrder = Object.freeze(nextOrder);
        root.persistGrants();
        return true;
    }

    function clearSessionGrants(): void {
        root.sessionGrants = ({});
        root.sessionGrantOrder = Object.freeze([]);
        root.persistGrants();
    }

    Component.onCompleted: root.loadPersistedGrants()

    property FileView grantsFile: FileView {
        path: root.grantsFilePath
        preload: true
        blockLoading: false
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onLoaded: root.loadPersistedGrants()
        onFileChanged: root.loadPersistedGrants()
    }

    function snapshot(): string {
        return JSON.stringify({
            available: server.active,
            socketPath: root.socketPath,
            pending: root.pending,
            popupScreenName: root.popupScreenName,
            sessionGrantCount: root.sessionGrantOrder.length
        });
    }

    property SocketServer server: SocketServer {
        id: server
        active: true
        path: root.socketPath
        handler: Component {
            Socket {
                id: connection
                onConnectionStateChanged: {
                    if (!connection.connected)
                        root.disconnected(connection);
                }
                parser: SplitParser {
                    splitMarker: "\n"
                    onRead: data => root.receive(connection, data)
                }
            }
        }
    }
}
