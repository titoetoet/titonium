#!/usr/bin/env bash
set -euo pipefail
export QT_LOGGING_RULES="${QT_LOGGING_RULES:-qt.qpa.services=false}"

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
user_home="$(getent passwd "$(id -u)" | cut -d: -f6)"
data_root="${XDG_DATA_HOME:-$user_home/.local/share}"
runtime_dir="$data_root/titonium"
runtime_history="$runtime_dir/clipboard-history.json"
backup_dir="$(mktemp -d --tmpdir titonium-spotlight-acceptance.XXXXXX)"
log_file="$backup_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$backup_dir/approval.sock"
had_history=false
shell_pid=""

mkdir -p -- "$runtime_dir"
if [[ -f "$runtime_history" ]]; then
    cp -- "$runtime_history" "$backup_dir/clipboard-history.json"
    had_history=true
fi

before_git="$(git -C "$project_root" status --porcelain=v1)"

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    if [[ $had_history == true ]]; then
        cp -- "$backup_dir/clipboard-history.json" "$runtime_history"
    else
        rm -f -- "$runtime_history"
    fi
    rm -f -- "$backup_dir/clipboard-history.json" "$log_file" "$backup_dir/approval.sock"
    rmdir -- "$backup_dir"
}
trap cleanup EXIT

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
}

require_contains() {
    local actual="$1"
    local expected="$2"
    local context="$3"
    if [[ "$actual" != *"$expected"* ]]; then
        printf 'FAIL %s: expected %q in %q\n' "$context" "$expected" "$actual" >&2
        exit 1
    fi
}

wait_for_spotlight_state() {
    local expected="$1"
    local context="$2"
    local actual=""
    for _ in {1..40}; do
        actual="$(call_ipc spotlight state 2>/dev/null || true)"
        if [[ "$actual" == *";$expected" ]]; then
            printf '%s\n' "$actual"
            return 0
        fi
        sleep 0.05
    done
    printf 'FAIL %s: state did not settle at %q; last state %q\n' \
        "$context" "$expected" "$actual" >&2
    return 1
}

qs -p "$project_root" --no-color >"$log_file" 2>&1 &
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
    echo "FAIL Spotlight acceptance shell did not become ready" >&2
    exit 1
fi

open_state="$(call_ipc spotlight toggle)"
require_contains "$open_state" "open:applications:" "Spotlight toggle"
require_contains "$(call_ipc spotlight state)" "open:applications:" "Spotlight open state"

call_ipc spotlight setQuery fire >/dev/null
results_state="$(wait_for_spotlight_state \
    "mode=results;query=fire;selected=0" "Spotlight search state")"
require_contains "$results_state" "mode=results;query=fire;selected=0" "Spotlight search state"

require_contains "$(call_ipc spotlight setScope clipboard)" "open:clipboard:" "Spotlight Tab scope Clipboard"
wait_for_spotlight_state "mode=clipboard;query=fire;selected=-1" "Clipboard scope preserves query without implicit selection" >/dev/null
require_contains "$(call_ipc spotlight setScope system)" "open:system:" "Spotlight Tab scope System Search"
wait_for_spotlight_state "mode=system;query=fire;selected=0" "System Search scope preserves query" >/dev/null
require_contains "$(call_ipc spotlight setScope applications)" "open:applications:" "Spotlight Tab scope wraps to Apps"
wait_for_spotlight_state "mode=results;query=fire;selected=0" "Apps scope restores results" >/dev/null

require_contains "$(call_ipc spotlight close)" "closed" "Spotlight close"
require_contains "$(call_ipc spotlight state)" "closed" "Spotlight closed state"

require_contains "$(call_ipc spotlight clipboard)" "open:clipboard:" "Spotlight clipboard"
require_contains "$(call_ipc spotlight state)" "open:clipboard:" "Spotlight clipboard state"
require_contains "$(call_ipc spotlight state)" "mode=clipboard" "Spotlight clipboard mode"
require_contains "$(call_ipc spotlight close)" "closed" "Spotlight clipboard close"
require_contains "$(call_ipc spotlight state)" "closed" "Spotlight clipboard closed state"

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Spotlight acceptance changed repository files" >&2
    exit 1
fi

if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable|Property 'spotlightSurface' does not exist on AppGrid"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL runtime error found" >&2
    exit 1
fi

echo "PASS Spotlight Apps/Clipboard/System scopes, search state, close and history isolation acceptance"
