#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-system-monitor-acceptance.XXXXXX)"
log_file="$test_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_dir/approval.sock"
shell_pid=""
production_was_running=false
before_git="$(git -C "$project_root" status --porcelain=v1)"
before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    rm -f -- "$log_file" "$test_dir/approval.sock"
    [[ "$production_was_running" == true ]] && qs -d -p "$project_root" >/dev/null 2>&1 || true
    rmdir -- "$test_dir"
}
trap cleanup EXIT

call_ipc() { qs -p "$project_root" ipc --pid "$shell_pid" call "$@"; }

if qs -p "$project_root" ipc call app status >/dev/null 2>&1; then
    production_was_running=true
    qs -p "$project_root" kill >/dev/null 2>&1 || true
    for _ in {1..50}; do
        qs -p "$project_root" ipc call app status >/dev/null 2>&1 || break
        sleep 0.1
    done
fi

qs -n -p "$project_root" --no-color >"$log_file" 2>&1 &
shell_pid=$!
ready=false
for _ in {1..50}; do
    if [[ "$(call_ipc app status 2>/dev/null || true)" == "ready" ]]; then ready=true; break; fi
    sleep 0.1
done
[[ "$ready" == true ]] || { sed -n '1,240p' "$log_file" >&2; exit 1; }

open_state="$(call_ipc centerNotch open monitoring)"
[[ "$open_state" == *";page=overview"* ]] || {
    printf 'FAIL Center did not normalize Monitoring to Dashboard: %q\n' "$open_state" >&2
    exit 1
}

monitor_state="$(call_ipc center monitorState)"
python3 -c '
import json, sys
state = json.loads(sys.argv[1])
keys = ("active", "live", "psRunning", "discoveryRunning", "gpuInfoRunning", "storageRunning")
raise SystemExit(0 if all(state.get(key) is False for key in keys) else 1)
' "$monitor_state" || {
    printf 'FAIL detached System Monitor became active: %s\n' "$monitor_state" >&2
    exit 1
}
call_ipc centerNotch close >/dev/null

[[ "$(git -C "$project_root" status --porcelain=v1)" == "$before_git" ]] || exit 1
[[ "$(sha256sum -- "$live_hypr")" == "$before_live" ]] || exit 1
[[ "$(sha256sum -- "$dotfiles_hypr")" == "$before_dotfiles" ]] || exit 1
rg -q 'Configuration Loaded' "$log_file"
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
! rg -i "$runtime_rejection_pattern" "$log_file"
echo "PASS System Monitor remains detached from Dashboard-only Center"
