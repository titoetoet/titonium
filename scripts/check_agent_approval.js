const fs = require("fs");
const vm = require("vm");

const source = fs.readFileSync("Titonium/Services/AgentApproval/ApprovalRules.js", "utf8")
    .replace(/^\.pragma library\s*$/m, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
if (source.includes("function buildPermissionOverrides"))
    throw new Error("dead legacy permission override helper must stay removed");
if (!source.includes("function buildAntigravityExecutionOverrides"))
    throw new Error("missing explicit Antigravity execution override helper");

const command = context.normalize({
    source: "chatgpt", requestId: "7", method: "item/commandExecution/requestApproval",
    params: { command: "npm test", cwd: "/tmp/project" }
});
if (command.title !== "ChatGPT" || command.command !== "npm test" || command.cwd !== "/tmp/project")
    throw new Error("ChatGPT approval normalization failed");
if (context.decisionPayload("chatgpt", "allow_once").decision !== "accept")
    throw new Error("allow-once mapping failed");
if (context.decisionPayload("chatgpt", "allow_session").decision !== "acceptForSession")
    throw new Error("session mapping failed");
if (context.decisionPayload("chatgpt", "ask").decision !== "delegate")
    throw new Error("ChatGPT review mapping must delegate to the native Desktop approval UI");
if (context.decisionPayload("antigravity", "deny").decision !== "deny")
    throw new Error("Antigravity deny mapping failed");
if (context.decisionPayload("antigravity", "ask").decision !== "force_ask")
    throw new Error("Antigravity ask mapping failed");
const sessionDecision = context.decisionPayload("antigravity", "allow_session", { command: "npm test" });
if (sessionDecision.decision !== "allow" || !sessionDecision.permissionOverrides
        || !sessionDecision.permissionOverrides.includes("command(*)")
        || !sessionDecision.permissionOverrides.includes("*"))
    throw new Error("Antigravity allow_session mapping failed");

const agyCommand = context.normalize({
    source: "antigravity",
    requestId: "123",
    conversationId: "conv-1",
    stepIdx: 5,
    workspacePaths: ["/home/cole/Projects/titonium"],
    toolCall: {
        name: "run_command",
        args: {
            CommandLine: "git status",
            Cwd: "/home/cole/Projects/titonium",
            toolAction: "Checking git status",
            toolSummary: "Check git status"
        }
    }
});
if (agyCommand.title !== "Antigravity" || agyCommand.kind !== "run_command"
        || agyCommand.command !== "git status" || agyCommand.cwd !== "/home/cole/Projects/titonium"
        || agyCommand.summary !== "Check git status" || agyCommand.detail !== "Checking git status")
    throw new Error("Antigravity run_command normalization failed");
const antigravityOnce = context.decisionPayload("antigravity", "allow_once", agyCommand);
if (antigravityOnce.decision !== "allow"
        || !antigravityOnce.permissionOverrides.includes("command(git status)")
        || !antigravityOnce.permissionOverrides.includes("command(*)")
        || !antigravityOnce.permissionOverrides.includes("*"))
    throw new Error("Antigravity allow_once must include one-click execution overrides");
const antigravitySession = context.decisionPayload("antigravity", "allow_session", agyCommand);
if (!antigravitySession.permissionOverrides.includes("command(*)")
        || !antigravitySession.permissionOverrides.includes("*"))
    throw new Error("Antigravity allow_session must include one-click execution overrides");
if (context.sessionGrantKey(agyCommand) !== "conv-1\u0000command:git")
    throw new Error("Antigravity session grants must be scoped by conversation and binary");
if (context.requiresExplicitApproval(agyCommand))
    throw new Error("ordinary commands must be eligible for an explicit session grant");

const agyWrite = context.normalize({
    source: "antigravity",
    requestId: "124",
    toolCall: {
        name: "write_to_file",
        args: {
            TargetFile: "/tmp/test.txt",
            Description: "Writing a test file",
            toolSummary: "Write file"
        }
    }
});
if (agyWrite.kind !== "write_to_file" || agyWrite.command !== "/tmp/test.txt"
        || agyWrite.targetFile !== "/tmp/test.txt" || agyWrite.detail !== "Writing a test file")
    throw new Error("Antigravity write_to_file normalization failed");

const agyReplace = context.normalize({
    source: "antigravity",
    requestId: "125",
    toolCall: {
        name: "replace_file_content",
        args: {
            TargetFile: "/tmp/test.txt",
            Instruction: "Replace text",
            toolSummary: "Edit file"
        }
    }
});
if (agyReplace.kind !== "replace_file_content" || agyReplace.targetFile !== "/tmp/test.txt"
        || agyReplace.detail !== "Replace text")
    throw new Error("Antigravity replace_file_content normalization failed");

const askPayload = context.decisionPayload("antigravity", "ask", agyCommand);
if (askPayload.decision !== "force_ask")
    throw new Error("Antigravity review should map to force_ask, got: " + JSON.stringify(askPayload));

const serviceSource = fs.readFileSync(
    "Titonium/Services/AgentApproval/AgentApprovalService.qml", "utf8");
if (serviceSource.includes("canAutoApprove") || serviceSource.includes("requires_sudo"))
    throw new Error("AgentApprovalService must not contain the old blanket auto-approve path");
for (const token of ["sessionGrants", "sessionGrantKey", "rememberSessionGrant",
        "requiresExplicitApproval", "sessionGrantCount", "sourceWindowScreenName",
        "popupScreenNameFor", "HyprlandService.windows", "syncCenterAttention",
        'CenterAttentionService.clear("agent:approval")',
        'kind: "approval_required"', 'I18n.tr("agent_approval.center.waiting"'] )
    if (!serviceSource.includes(token))
        throw new Error("AgentApprovalService missing session cache contract: " + token);
if (!serviceSource.includes('["antigravity-ide", "antigravity ide"]')
        || !serviceSource.includes('["chatgpt"]'))
    throw new Error("AgentApprovalService must route approvals to their source app monitor");
const sudoCommand = context.normalize({
    source: "antigravity",
    requestId: "126",
    conversationId: "conv-1",
    toolCall: { name: "run_command", args: { CommandLine: "sudo pacman -Syu" } }
});
if (!context.requiresExplicitApproval(sudoCommand))
    throw new Error("sudo commands must bypass session grants and show the popup");
console.log("agent approval rules: ok");
