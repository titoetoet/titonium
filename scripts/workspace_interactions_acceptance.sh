#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d --tmpdir titonium-workspace-interactions.XXXXXX)"
log_file="$test_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_dir/approval.sock"
shell_pid=""
before_git="$(git -C "$project_root" status --porcelain=v1)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
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

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
}

screen_layers() {
    local screen_name="$1"
    hyprctl -j layers | python3 -c '
import json, sys
print(json.dumps(json.load(sys.stdin).get(sys.argv[1], {}), sort_keys=True))
' "$screen_name"
}

qs -n -p "$project_root" --no-color >"$log_file" 2>&1 &
shell_pid=$!
for _ in {1..40}; do
    [[ "$(call_ipc app status 2>/dev/null || true)" == "ready" ]] && break
    sleep 0.1
done
if [[ "$(call_ipc app status 2>/dev/null || true)" != "ready" ]]; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL workspace interaction acceptance shell did not become ready" >&2
    exit 1
fi

printf '%s' "$(call_ipc window-switcher state)" | python3 -c '
import json, sys
state = json.load(sys.stdin)
if not isinstance(state.get("windows"), list): raise SystemExit(1)
for row in state["windows"]:
    if not isinstance(row.get("workspaceId"), int): raise SystemExit(1)
    if not isinstance(row.get("monitorName"), str): raise SystemExit(1)
    if "native" in row or "wayland" in row or "workspace" in row: raise SystemExit(1)
'
printf '%s' "$(call_ipc dock state)" | python3 -c '
import json, sys
state = json.load(sys.stdin)
if not isinstance(state.get("items"), list): raise SystemExit(1)
'

center_state="$(call_ipc centerNotch open overview)"
[[ "$center_state" == open:DP-1\;mode=expanded ]]
[[ "$(call_ipc centerNotch close)" == "closed" ]]
[[ "$(call_ipc centerNotch state)" == "closed" ]]

dp1_layers="$(screen_layers DP-1)"
dp3_layers="$(screen_layers DP-3)"
[[ "$dp1_layers" == *"titonium-menubar"* ]]
[[ "$dp1_layers" == *"titonium-dock"* ]]
if [[ "$dp3_layers" == *"titonium-"* ]]; then
    echo "FAIL workspace interaction acceptance found a Titonium DP-3 layer" >&2
    exit 1
fi

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    echo "FAIL workspace interaction acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL workspace interaction acceptance changed a Hyprland configuration" >&2
    exit 1
fi
rg -q 'Configuration Loaded' "$log_file"
runtime_rejection_pattern='\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\b|Type .* unavailable'
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL workspace interaction acceptance runtime error found" >&2
    exit 1
fi

echo "PASS workspace descriptors, Center lifecycle and DP-1-only layers"
