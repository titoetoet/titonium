#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d --tmpdir titonium-switcher-acceptance.XXXXXX)"
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
    echo "FAIL Window Switcher acceptance shell did not become ready" >&2
    exit 1
fi

initial_state="$(call_ipc window-switcher state)"
printf '%s' "$initial_state" | python3 -c '
import json, sys
state = json.load(sys.stdin)
if set(("active", "selectedId", "windows")) - set(state): raise SystemExit(1)
if not isinstance(state["windows"], list): raise SystemExit(1)
if not state["windows"]: raise SystemExit(2)
if any("wayland" in row or "native" in row for row in state["windows"]): raise SystemExit(1)
'

next_state="$(call_ipc window-switcher next)"
printf '%s' "$next_state" | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("active") is not True or not state.get("selectedId"): raise SystemExit(1)
'
[[ "$(screen_layers DP-1)" == *"titonium-overlay"* ]]
if [[ "$(screen_layers DP-3)" == *"titonium-"* ]]; then
    echo "FAIL Window Switcher created a Titonium DP-3 layer" >&2
    exit 1
fi
call_ipc window-switcher previous >/dev/null
[[ "$(call_ipc window-switcher close)" == "closed" ]]
printf '%s' "$(call_ipc window-switcher state)" | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("active") is not False or state.get("selectedId") != "": raise SystemExit(1)
'

[[ "$(git -C "$project_root" status --porcelain=v1)" == "$before_git" ]]
[[ "$(sha256sum -- "$live_hypr")" == "$before_live" ]]
[[ "$(sha256sum -- "$dotfiles_hypr")" == "$before_dotfiles" ]]
rg -q 'Configuration Loaded' "$log_file"
runtime_rejection_pattern='\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\b|Type .* unavailable'
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Window Switcher acceptance runtime error found" >&2
    exit 1
fi

echo "PASS Window Switcher read-only model, selection wrap and DP-1 lifecycle"
