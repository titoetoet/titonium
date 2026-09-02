#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d --tmpdir titonium-dock-acceptance.XXXXXX)"
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
import json
import sys
payload = json.load(sys.stdin)
print(json.dumps(payload.get(sys.argv[1], {}), sort_keys=True))
' "$screen_name"
}

valid_dock_state() {
    printf '%s' "$1" | python3 -c '
import json
import sys
state = json.load(sys.stdin)
if not isinstance(state.get("items"), list) or not isinstance(state.get("activeWorkspaceWindowCount"), int):
    raise SystemExit(1)
'
}

qs -n -p "$project_root" --no-color >"$log_file" 2>&1 &
shell_pid=$!

ready=false
for _ in {1..40}; do
    if [[ "$(call_ipc app status 2>/dev/null || true)" == "ready" ]]; then
        ready=true
        break
    fi
    sleep 0.1
done
if [[ $ready != true ]]; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Dock acceptance shell did not become ready" >&2
    exit 1
fi

dock_state="$(call_ipc dock state)"
if ! valid_dock_state "$dock_state"; then
    printf 'FAIL Dock state has unexpected shape: %q\n' "$dock_state" >&2
    exit 1
fi

dp1_layers="$(screen_layers DP-1)"
dp3_layers="$(screen_layers DP-3)"
if [[ "$dp1_layers" != *"titonium-dock"* ]]; then
    printf 'FAIL DP-1 does not own the Titonium Dock layer: %q\n' "$dp1_layers" >&2
    exit 1
fi
if [[ "$dp3_layers" == *"titonium-"* ]]; then
    printf 'FAIL DP-3 has a Titonium layer: %q\n' "$dp3_layers" >&2
    exit 1
fi

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Dock acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Dock acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Dock acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern='\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\b|Type .* unavailable'
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Dock acceptance runtime error found" >&2
    exit 1
fi

echo "PASS Dock read-only state and DP-1-only layer acceptance"
