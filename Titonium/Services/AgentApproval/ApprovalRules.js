.pragma library

function text(value) {
    return value === undefined || value === null ? "" : String(value);
}

function unquote(value) {
    if (value === undefined || value === null)
        return "";
    let str = String(value).trim();
    if (str.length >= 2 && str.startsWith('"') && str.endsWith('"')) {
        try {
            str = JSON.parse(str);
        } catch (_) {
            str = str.slice(1, -1);
        }
    }
    return String(str).trim();
}

function normalize(payload) {
    const source = text(payload.source || "antigravity");
    const toolCall = payload.toolCall || {};
    const toolArgs = toolCall.args || {};
    const params = payload.params || payload;

    let command = "";
    let cwd = "";
    let targetFile = "";
    const toolName = text(toolCall.name || payload.kind || payload.method || "command");
    const summary = unquote(toolArgs.toolSummary || toolArgs.toolAction || params.reason || params.justification || "");
    let detail = "";

    if (toolCall.name) {
        if (toolCall.name === "run_command" || toolCall.name === "run_shell_command") {
            command = unquote(toolArgs.CommandLine || toolArgs.command || toolArgs.cmd || "");
            cwd = unquote(toolArgs.Cwd || toolArgs.cwd || "");
            detail = unquote(toolArgs.toolAction || toolArgs.Description || "");
        } else if (toolCall.name === "write_to_file") {
            targetFile = unquote(toolArgs.TargetFile || toolArgs.path || "");
            command = targetFile;
            cwd = unquote(toolArgs.Cwd || "");
            detail = unquote(toolArgs.Description || toolArgs.toolAction || "");
        } else if (toolCall.name === "replace_file_content" || toolCall.name === "multi_replace_file_content") {
            targetFile = unquote(toolArgs.TargetFile || toolArgs.path || "");
            command = targetFile;
            cwd = unquote(toolArgs.Cwd || "");
            detail = unquote(toolArgs.Instruction || toolArgs.Description || toolArgs.toolAction || "");
        } else {
            command = unquote(toolArgs.CommandLine || toolArgs.command || JSON.stringify(toolArgs));
            cwd = unquote(toolArgs.Cwd || "");
            detail = unquote(toolArgs.toolAction || toolArgs.toolSummary || "");
        }
        if (!cwd && Array.isArray(payload.workspacePaths) && payload.workspacePaths.length > 0)
            cwd = unquote(payload.workspacePaths[0]);
    } else {
        command = unquote(params.command || params.cmd || params.tool_input?.command
            || params.toolInput?.command || params.path || params.reason || "");
        cwd = unquote(params.cwd || params.working_directory || params.tool_input?.cwd || "");
        detail = unquote(params.reason || params.justification || "");
    }

    return Object.freeze({
        requestId: text(payload.requestId || payload.id),
        source: source,
        kind: toolName,
        title: source === "chatgpt" ? "ChatGPT" : "Antigravity",
        command: command,
        cwd: cwd,
        targetFile: targetFile,
        summary: summary,
        detail: detail,
        reason: text(params.reason || params.justification || detail || summary),
        conversationId: text(payload.conversationId || ""),
        stepIdx: payload.stepIdx !== undefined ? Number(payload.stepIdx) : -1,
        workspacePaths: Array.isArray(payload.workspacePaths) ? payload.workspacePaths : [],
        raw: payload
    });
}

function buildOncePermissionOverrides(descriptor) {
    if (!descriptor)
        return [];
    const overrides = [];
    if (descriptor.command) {
        const cmd = descriptor.command.trim();
        overrides.push("command(" + cmd + ")");
    }
    if (descriptor.targetFile) {
        const file = descriptor.targetFile.trim();
        overrides.push("file_write(" + file + ")");
        overrides.push("file_edit(" + file + ")");
        overrides.push("file(" + file + ")");
    }
    return overrides;
}

function buildAntigravityExecutionOverrides(descriptor) {
    const overrides = buildOncePermissionOverrides(descriptor).slice();
    if (descriptor && descriptor.command) {
        const cmd = descriptor.command.trim();
        const binary = cmd.split(/\s+/)[0];
        if (binary && binary !== cmd)
            overrides.push("command(" + binary + ")");
        overrides.push("command(*)");
    }
    if (descriptor && descriptor.kind) {
        overrides.push(descriptor.kind + "(*)");
        overrides.push(descriptor.kind);
    }
    overrides.push("*");
    return overrides;
}

function isFileChange(descriptor) {
    if (!descriptor)
        return false;
    const kind = text(descriptor.kind);
    return kind === "write_to_file"
        || kind === "replace_file_content"
        || kind === "multi_replace_file_content"
        || Boolean(descriptor.targetFile);
}

function sessionScope(descriptor) {
    if (!descriptor)
        return "";
    if (descriptor.conversationId)
        return text(descriptor.conversationId);
    if (Array.isArray(descriptor.workspacePaths) && descriptor.workspacePaths.length > 0 && descriptor.workspacePaths[0])
        return text(descriptor.workspacePaths[0]);
    if (descriptor.cwd)
        return text(descriptor.cwd);
    return "antigravity";
}

function commandBinary(descriptor) {
    if (!descriptor || !descriptor.command)
        return "";
    const cmd = descriptor.command.trim();
    return cmd ? cmd.split(/\s+/)[0] : "";
}

function sessionGrantKey(descriptor) {
    if (!descriptor || !descriptor.conversationId)
        return "";
    const binary = commandBinary(descriptor);
    if (!binary)
        return "";
    return descriptor.conversationId + "\u0000command:" + binary;
}

function sessionKeys(descriptor) {
    if (!descriptor)
        return [];
    const keys = [];
    const standardKey = sessionGrantKey(descriptor);
    if (standardKey)
        keys.push(standardKey);
    if (descriptor.conversationId)
        keys.push("conv:" + descriptor.conversationId);

    const scope = sessionScope(descriptor);
    if (scope) {
        if (isFileChange(descriptor)) {
            keys.push(scope + "\u0000file_edit");
        } else {
            const binary = commandBinary(descriptor);
            if (binary)
                keys.push(scope + "\u0000command:" + binary);
        }
        keys.push("scope:" + scope);
    }
    return keys;
}

function requiresExplicitApproval(descriptor) {
    return !!descriptor && /\bsudo\b/.test(descriptor.command || "");
}

function decisionPayload(source, decision, descriptor) {
    if (source === "chatgpt") {
        if (decision === "ask")
            return { decision: "delegate" };
        return { decision: decision === "allow_once" ? "accept"
            : (decision === "allow_session" ? "acceptForSession" : "decline") };
    }
    if (decision === "deny")
        return { decision: "deny" };
    if (decision === "ask")
        return { decision: "force_ask", reason: "User requested review in Antigravity" };
    if (decision === "allow_once")
        return { decision: "allow", permissionOverrides: buildAntigravityExecutionOverrides(descriptor) };
    const overrides = buildAntigravityExecutionOverrides(descriptor);
    return { decision: "allow", permissionOverrides: overrides };
}
