#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-center-timer-acceptance.XXXXXX)"
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
    case "$test_dir" in
        /tmp/titonium-center-timer-acceptance.*) rm -rf -- "$test_dir" ;;
    esac
}
trap cleanup EXIT

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
}

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
if [[ $ready != true ]]; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Timer acceptance shell did not become ready" >&2
    exit 1
fi

call_ipc timer state | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("activeCount") != 0 or state.get("timers") != []:
    raise SystemExit(1)
'

call_ipc timer start first 60 "First timer" >/dev/null
call_ipc timer start second 120 "Second timer" >/dev/null
call_ipc timer cancel first >/dev/null
call_ipc timer state | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("activeCount") != 1:
    raise SystemExit(1)
if [timer.get("id") for timer in state.get("timers", [])] != ["second"]:
    raise SystemExit(1)
'
call_ipc timer cancel second >/dev/null

call_ipc timer start acceptance 1 "Acceptance timer" >/dev/null
active_center="$(call_ipc center state)"
printf '%s' "$active_center" | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("current") is not None:
    raise SystemExit(1)
if not any(item.get("id") == "timer" for item in state.get("indicators", [])):
    raise SystemExit(1)
'

finished=false
timer_state=""
center_state=""
for _ in {1..40}; do
    timer_state="$(call_ipc timer state)"
    center_state="$(call_ipc center state)"
    if printf '%s\n%s' "$timer_state" "$center_state" | python3 -c '
import json, sys
timer = json.loads(sys.stdin.readline())
center = json.loads(sys.stdin.readline())
current = center.get("current") or {}
ok = (
    timer.get("activeCount") == 0
    and current.get("kind") == "timer_finished"
    and current.get("priority") == 70
    and current.get("actionable") is True
)
raise SystemExit(0 if ok else 1)
'; then
        finished=true
        break
    fi
    sleep 0.1
done
if [[ $finished != true ]]; then
    printf 'FAIL Timer did not finish: timer=%q center=%q\n' "$timer_state" "$center_state" >&2
    exit 1
fi

call_ipc timer acknowledge acceptance >/dev/null
call_ipc center state | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("current") is not None:
    raise SystemExit(1)
if any(item.get("id") == "timer" for item in state.get("indicators", [])):
    raise SystemExit(1)
'

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Timer acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Timer acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Timer acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Timer runtime error found" >&2
    exit 1
fi

echo "PASS Center Timer IPC, indicator, completion and acknowledgement acceptance"
