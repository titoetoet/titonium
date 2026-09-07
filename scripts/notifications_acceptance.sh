#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Validate the style-aware, read-only presentation contract before creating
# fixture state, so a preflight failure cannot leave a temporary directory.
node "$project_root/scripts/check_notification_theme_contract.js"

if [[ -z "${WAYLAND_DISPLAY:-}" || -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    echo "SKIP notifications acceptance: no active Wayland/Hyprland session" >&2
    exit 0
fi
if ! hyprctl -j monitors >/dev/null 2>&1; then
    echo "SKIP notifications acceptance: compositor state is unavailable" >&2
    exit 0
fi

# org.freedesktop.Notifications is owned once per session. This focused fixture
# must never replace a shell the user is already running.
notification_name_owner="$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications 2>&1)" || {
    printf 'SKIP notifications acceptance: cannot determine notification D-Bus owner: %s\n' \
        "$notification_name_owner" >&2
    exit 0
}
case "$notification_name_owner" in
    "b true")
        echo "SKIP notifications acceptance: session notification D-Bus name is already owned" >&2
        exit 0
        ;;
    "b false") ;;
    *)
        printf 'SKIP notifications acceptance: NameHasOwner did not return an explicit boolean: %s\n' \
            "$notification_name_owner" >&2
        exit 0
        ;;
esac

live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-notifications-acceptance.XXXXXX)"
runtime_dir="$test_dir/data/titonium"
log_file="$test_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_dir/approval.sock"
shell_pid=""

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    case "$test_dir" in
        /tmp/titonium-notifications-acceptance.*) rm -rf -- "$test_dir" ;;
    esac
}
trap cleanup EXIT

before_git="$(git -C "$project_root" status --porcelain=v1)"
before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
}

trigger_notification_control() {
    local status provider reply
    # Match Quickshell's Hyprland.usingLua detection, rather than infer the active
    # parser from the installed version or a config filename.
    if ! status="$(hyprctl -j status 2>&1)"; then
        if [[ "$status" != "unknown request" ]]; then
            printf 'FAIL cannot query notification shortcut dispatcher: %s\n' "$status" >&2
            return 1
        fi
    fi
    if [[ "$status" == "unknown request" ]]; then
        # Hyprland versions predating Lua have no status request.
        provider="hyprlang"
    elif ! provider="$(python3 -c '
import json, sys
try:
    provider = json.loads(sys.argv[1]).get("configProvider")
except (ValueError, AttributeError):
    raise SystemExit(1)
if provider not in ("lua", "hyprlang"):
    raise SystemExit(1)
print(provider)
' "$status")"; then
        printf 'FAIL unknown notification shortcut config provider: %s\n' "$status" >&2
        return 1
    fi
    local -a command=(hyprctl dispatch global titonium:notifications)
    if [[ "$provider" == "lua" ]]; then
        command=(hyprctl dispatch 'hl.dsp.global("titonium:notifications")')
    fi
    if ! reply="$("${command[@]}" 2>&1)"; then
        printf 'FAIL notification shortcut dispatch (%s): %s\n' "$provider" "$reply" >&2
        return 1
    fi
}

panel_matches() {
    local expected_open="$1"
    local expected_owner="$2"
    local expected_unread="$3"
    local state
    state="$(call_ipc notifications state 2>/dev/null || true)"
    python3 -c '
import json, sys
try:
    state = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)
panel = state.get("panel")
expected_open = sys.argv[2] == "true"
raise SystemExit(0 if (
    isinstance(panel, dict)
    and panel.get("open") is expected_open
    and panel.get("ownerId") == sys.argv[3]
    and state.get("unreadCount") == int(sys.argv[4])
) else 1)
' "$state" "$expected_open" "$expected_owner" "$expected_unread"
}

wait_for_panel() {
    local expected_open="$1"
    local expected_owner="$2"
    local expected_unread="$3"
    for _ in {1..60}; do
        if panel_matches "$expected_open" "$expected_owner" "$expected_unread"; then
            return 0
        fi
        sleep 0.1
    done
    call_ipc notifications state >&2 || true
    return 1
}

set_runtime_style() {
    local style="$1"
    case "$style" in
        connected|classic) ;;
        *) return 1 ;;
    esac
    sed -i -E '0,/"style": "(connected|classic)"/s//"style": "'"$style"'"/' \
        "$runtime_dir/settings.json"
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
    and isinstance(policy, dict) and policy.get("mode") == "automatic"
    and policy.get("allowCriticalOnIsland") is True
    and policy.get("keepCriticalUnread") is True
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
    and isinstance(policy, dict) and policy.get("mode") == "automatic"
    and policy.get("allowCriticalOnIsland") is True
    and policy.get("keepCriticalUnread") is True
) else 1)
' "$state"
}

queue_matches() {
    local expected_count="$1"
    local expected_key="$2"
    local state
    state="$(call_ipc notifications state 2>/dev/null || true)"
    python3 -c '
import json, sys
try:
    state = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)
queue = state.get("queue")
raise SystemExit(0 if isinstance(queue, dict)
    and queue.get("count") == int(sys.argv[2])
    and queue.get("currentKey") == sys.argv[3] else 1)
' "$state" "$expected_count" "$expected_key"
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

layer_present() {
    local monitor="$1"
    local namespace="$2"
    [[ "$(screen_layers "$monitor")" == *"$namespace"* ]]
}

wait_for_style() {
    local style="$1"
    for _ in {1..60}; do
        if [[ "$style" == "connected" ]] && layer_present DP-1 "titonium-edge-menu"; then
            return 0
        fi
        if [[ "$style" == "classic" ]] && ! layer_present DP-1 "titonium-edge-menu"; then
            return 0
        fi
        sleep 0.1
    done
    return 1
}

mkdir -p -- "$runtime_dir" "$test_dir/state" "$test_dir/cache"
cp -- "$project_root/config/defaults/settings.json" "$runtime_dir/settings.json"

XDG_DATA_HOME="$test_dir/data" \
XDG_STATE_HOME="$test_dir/state" \
XDG_CACHE_HOME="$test_dir/cache" \
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
if ! wait_for_style connected; then
    echo "FAIL temporary shell did not publish the default Connected style" >&2
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
if ! panel_matches false "" 1; then
    echo "FAIL notification panel was not initially closed with unread history" >&2
    exit 1
fi
trigger_notification_control
if ! wait_for_panel true notification-panel:DP-1 0; then
    echo "FAIL Connected notification shortcut did not mount and mark history read" >&2
    exit 1
fi
if ! layer_present DP-1 "titonium-edge-menu" \
        || layer_present DP-1 "titonium-overlay"; then
    echo "FAIL Connected notification history did not use only the Edge chassis" >&2
    exit 1
fi
trigger_notification_control
if ! wait_for_panel false "" 0; then
    echo "FAIL same-control Connected notification toggle did not tear down history" >&2
    exit 1
fi

if [[ "$(call_ipc audio popup)" != "open:DP-1" ]]; then
    echo "FAIL Audio IPC did not open an active Connected Edge surface" >&2
    exit 1
fi
trigger_notification_control
if ! wait_for_panel true notification-panel:DP-1 0; then
    echo "FAIL notification shortcut did not replace the active Connected Edge surface" >&2
    exit 1
fi
if [[ "$(call_ipc audio popupState)" != "closed" ]]; then
    echo "FAIL displaced Connected Audio owner remained active" >&2
    exit 1
fi
trigger_notification_control
if ! wait_for_panel false "" 0; then
    echo "FAIL Connected cross-control fixture did not tear down" >&2
    exit 1
fi

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

first_critical_id="$(notify-send -p --urgency=critical --app-name="Titonium Acceptance" \
    --icon=dialog-warning "Titonium critical first" "Center FIFO first")"
second_critical_id="$(notify-send -p --urgency=critical --app-name="Titonium Acceptance" \
    --icon=dialog-warning "Titonium critical second" "Center FIFO second")"
case "$first_critical_id:$second_critical_id" in
    *[!0-9:]*|:*|*:) echo "FAIL critical fixtures did not return native notification IDs" >&2; exit 1 ;;
esac
first_critical_key="native:$first_critical_id"
second_critical_key="native:$second_critical_id"

first_current=false
for _ in {1..30}; do
    if state_matches 4 1 3 && queue_matches 2 "$first_critical_key"; then
        first_current=true
        break
    fi
    sleep 0.1
done
if [[ "$first_current" != true ]]; then
    call_ipc notifications state >&2 || true
    echo "FAIL first critical fixture was not the FIFO current item" >&2
    exit 1
fi

second_current=false
for _ in {1..70}; do
    if queue_matches 1 "$second_critical_key"; then
        second_current=true
        break
    fi
    sleep 0.1
done
if [[ "$second_current" != true ]]; then
    call_ipc notifications state >&2 || true
    echo "FAIL second critical fixture did not advance after first expiry" >&2
    exit 1
fi

queue_drained=false
for _ in {1..70}; do
    if state_matches 4 0 3 && queue_matches 0 ""; then
        queue_drained=true
        break
    fi
    sleep 0.1
done
if [[ "$queue_drained" != true ]]; then
    call_ipc notifications state >&2 || true
    echo "FAIL critical FIFO queue did not drain after final expiry" >&2
    exit 1
fi

trigger_notification_control
if ! wait_for_panel true notification-panel:DP-1 0; then
    echo "FAIL Connected history did not remount after critical routing" >&2
    exit 1
fi
set_runtime_style "classic"
if ! wait_for_panel false "" 0 || ! wait_for_style classic; then
    echo "FAIL Connected-to-Classic style transition did not release notification history" >&2
    exit 1
fi

trigger_notification_control
if ! wait_for_panel true notification-panel:DP-1 0; then
    echo "FAIL Classic notification shortcut did not mount detached history" >&2
    exit 1
fi
if ! layer_present DP-1 "titonium-overlay" \
        || layer_present DP-1 "titonium-edge-menu"; then
    echo "FAIL Classic notification history did not use only the detached overlay" >&2
    exit 1
fi
trigger_notification_control
if ! wait_for_panel false "" 0; then
    echo "FAIL same-control Classic notification toggle did not tear down history" >&2
    exit 1
fi

case "$(call_ipc spotlight toggle)" in
    open:applications:DP-1*) ;;
    *) echo "FAIL Spotlight IPC did not open the Classic cross-control fixture" >&2; exit 1 ;;
esac
trigger_notification_control
if ! wait_for_panel true notification-panel:DP-1 0; then
    echo "FAIL notification shortcut did not replace the Classic overlay owner" >&2
    exit 1
fi
if [[ "$(call_ipc spotlight state)" != "closed" ]]; then
    echo "FAIL displaced Classic Spotlight owner remained active" >&2
    exit 1
fi

set_runtime_style "connected"
if ! wait_for_panel false "" 0 || ! wait_for_style connected; then
    echo "FAIL Classic-to-Connected style transition did not release notification history" >&2
    exit 1
fi
trigger_notification_control
if ! wait_for_panel true notification-panel:DP-1 0; then
    echo "FAIL Connected notification history did not reopen after the style transition" >&2
    exit 1
fi
if layer_present DP-1 "titonium-overlay"; then
    echo "FAIL stale Classic notification overlay survived the Connected reopen" >&2
    exit 1
fi
trigger_notification_control
if ! wait_for_panel false "" 0; then
    echo "FAIL final Connected notification teardown did not complete" >&2
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

echo "PASS passive/critical routing plus live Connected/Classic notification owner lifecycle"
