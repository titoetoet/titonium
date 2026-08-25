.pragma library

function idle() {
    return { action: "", kind: "", phase: "idle" };
}

function transition(state, effect, action, error) {
    return {
        state: state,
        effect: effect,
        action: action || "",
        error: error || ""
    };
}

function begin(action) {
    return {
        action: String(action || ""),
        kind: action === "lock" ? "lock" : "short",
        phase: "starting"
    };
}

function started(state) {
    if (!state || state.phase !== "starting")
        return transition(state || idle(), "none", "", "");
    return transition({
        action: state.action,
        kind: state.kind,
        phase: state.kind === "lock" ? "settling" : "running"
    }, "none", "", "");
}

function exited(state, exitCode) {
    if (!state || state.phase === "idle")
        return transition(idle(), "none", "", "");
    if (state.kind === "lock" && state.phase === "accepted")
        return transition(idle(), "none", "", "");
    if (Number(exitCode) === 0)
        return transition(idle(), "accepted", state.action, "");
    return transition(idle(), "failed", state.action, "session.error.command_failed");
}

function stopped(state) {
    if (!state || state.phase !== "starting")
        return transition(state || idle(), "none", "", "");
    return transition(idle(), "failed", state.action, "session.error.start_failed");
}

function settled(state) {
    if (!state || state.kind !== "lock" || state.phase !== "settling")
        return transition(state || idle(), "none", "", "");
    return transition({
        action: state.action,
        kind: state.kind,
        phase: "accepted"
    }, "accepted", state.action, "");
}
