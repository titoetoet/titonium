#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-notifications-acceptance.XXXXXX)"
log_file="$test_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_dir/approval.sock"
shell_pid=""

before_git="$(git -C "$project_root" status --porcelain=v1)"
before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    rm -f -- "$log_file" "$test_dir/approval.sock"
    rmdir -- "$test_dir"
}
trap cleanup EXIT

# org.freedesktop.Notifications is owned once per session. This focused fixture
# must never replace a shell the user is already running.
if qs -p "$project_root" ipc call app status >/dev/null 2>&1; then
    echo "SKIP notifications acceptance: existing Titonium instance owns the notification D-Bus name" >&2
    exit 0
fi
if busctl --user status org.freedesktop.Notifications >/dev/null 2>&1; then
    echo "SKIP notifications acceptance: session notification D-Bus name is already owned" >&2
    exit 0
fi

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
}

state_matches() {
    local expected_descriptors="$1"
    local expected_toasts="$2"
    local expected_unread="$3"
    local state
    state="$(call_ipc notifications state 2>/dev/null || true)"
    python3 -c '
import json, sys
try:
    state = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)
expected = [int(value) for value in sys.argv[2:]]
actual = [state.get("descriptorCount"), state.get("toastCount"), state.get("unreadCount")]
panel = state.get("panel")
queue = state.get("queue")
policy = state.get("policy")
contract = (
    isinstance(panel, dict) and isinstance(panel.get("open"), bool)
    and isinstance(panel.get("ownerId"), str)
    and isinstance(queue, dict) and isinstance(queue.get("count"), int)
    and queue["count"] >= 0 and isinstance(queue.get("currentKey"), str)
    and isinstance(policy, dict) and policy.get("mode") in ("automatic", "custom")
    and isinstance(policy.get("allowCriticalOnIsland"), bool)
    and isinstance(policy.get("keepCriticalUnread"), bool)
)
raise SystemExit(0 if actual == expected and contract else 1)
' "$state" "$expected_descriptors" "$expected_toasts" "$expected_unread"
}

snapshot_contract() {
    local state
    state="$(call_ipc notifications state 2>/dev/null || true)"
    python3 -c '
import json, sys
try:
    state = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)
panel = state.get("panel")
queue = state.get("queue")
policy = state.get("policy")
raise SystemExit(0 if (
    isinstance(panel, dict) and isinstance(panel.get("open"), bool)
    and isinstance(panel.get("ownerId"), str)
    and isinstance(queue, dict) and isinstance(queue.get("count"), int)
    and queue["count"] >= 0 and isinstance(queue.get("currentKey"), str)
    and isinstance(policy, dict) and policy.get("mode") in ("automatic", "custom")
    and isinstance(policy.get("allowCriticalOnIsland"), bool)
    and isinstance(policy.get("keepCriticalUnread"), bool)
) else 1)
' "$state"
}

screen_layers() {
    local monitor="$1"
    hyprctl -j layers | python3 -c '
import json, sys
data = json.load(sys.stdin)
monitor = sys.argv[1]
names = []
for level in data.get(monitor, {}).get("levels", {}).values():
    for layer in level:
        names.append(str(layer.get("namespace", "")))
print("\n".join(names))
' "$monitor"
}

qs -n -p "$project_root" --no-color >"$log_file" 2>&1 &
shell_pid=$!

ready=false
for _ in {1..50}; do
    if [[ "$(call_ipc app status 2>/dev/null || true)" == "ready" ]]; then
        ready=true
        break
    fi
    sleep 0.1
done
if [[ "$ready" != true ]]; then
    sed -n '1,260p' "$log_file" >&2
    echo "FAIL notification acceptance shell did not become ready" >&2
    exit 1
fi
if ! snapshot_contract; then
    call_ipc notifications state >&2 || true
    echo "FAIL notifications state omitted read-only panel, queue, or policy metadata" >&2
    exit 1
fi

notify-send --app-name="Titonium Acceptance" --icon=dialog-information \
    "Titonium fixture" "toast acceptance"

received=false
for _ in {1..30}; do
    if state_matches 1 1 1; then
        received=true
        break
    fi
    sleep 0.1
done
if [[ "$received" != true ]]; then
    call_ipc notifications state >&2 || true
    echo "FAIL notification fixture was not projected" >&2
    exit 1
fi

if [[ "$(screen_layers DP-1)" != *"titonium-notification-toast"* ]]; then
    echo "FAIL DP-1 does not own the transient toast layer" >&2
    exit 1
fi
if [[ "$(screen_layers DP-3)" == *"titonium-notification-toast"* ]]; then
    echo "FAIL notification toast escaped to DP-3" >&2
    exit 1
fi

sleep 6
if ! state_matches 1 0 1; then
    call_ipc notifications state >&2 || true
    echo "FAIL toast expiry changed history or unread state" >&2
    exit 1
fi
[[ "$(call_ipc notifications markRead)" == "0" ]]
state_matches 1 0 0

notify-send --app-name="Titonium Acceptance" --icon=dialog-information \
    "Titonium second fixture" "history and unread acceptance"

received_second=false
for _ in {1..30}; do
    if state_matches 2 1 1; then
        received_second=true
        break
    fi
    sleep 0.1
done
if [[ "$received_second" != true ]]; then
    call_ipc notifications state >&2 || true
    echo "FAIL second notification did not extend history and unread state" >&2
    exit 1
fi

notify-send --urgency=critical --app-name="Titonium Acceptance" --icon=dialog-warning \
    "Titonium critical fixture" "Center FIFO acceptance"

critical_routed=false
for _ in {1..30}; do
    state="$(call_ipc notifications state 2>/dev/null || true)"
    if python3 -c '
import json, sys
try:
    state = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)
queue = state.get("queue", {})
raise SystemExit(0 if state.get("descriptorCount") == 3
    and state.get("toastCount") == 1 and state.get("unreadCount") == 2
    and queue.get("count") == 1 and str(queue.get("currentKey", "")).startswith("native:")
    else 1)
' "$state"; then
        critical_routed=true
        break
    fi
    sleep 0.1
done
if [[ "$critical_routed" != true ]]; then
    call_ipc notifications state >&2 || true
    echo "FAIL critical fixture was not routed to the Center FIFO queue" >&2
    exit 1
fi

sleep 5
if ! state_matches 3 0 2; then
    call_ipc notifications state >&2 || true
    echo "FAIL critical queue did not expire after its readable interval" >&2
    exit 1
fi

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL notification acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL notification acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q "Configuration Loaded" "$log_file"; then
    echo "FAIL missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,260p' "$log_file" >&2
    echo "FAIL notification runtime error found" >&2
    exit 1
fi

echo "PASS passive/critical notification routing, state seam, and DP-1-only acceptance"
