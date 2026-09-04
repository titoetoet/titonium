#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-center-notch-acceptance.XXXXXX)"
log_file="$test_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_dir/approval.sock"
shell_pid=""

before_git="$(git -C "$project_root" status --porcelain=v1)"
before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

if [[ "$(rg -l 'Shared\.ConnectedPillShape \{' "$project_root/Titonium/Bar" -g '*.qml' | wc -l)" -ne 1 ]] \
        || ! rg -q 'CenterPillWindow \{' "$project_root/Titonium/Bar/BarHost.qml"; then
    echo "FAIL Dynamic Island does not have exactly one visual owner and connected shape" >&2
    exit 1
fi

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

require_contains() {
    local actual="$1"
    local expected="$2"
    local context="$3"
    if [[ "$actual" != *"$expected"* ]]; then
        printf 'FAIL %s: expected %q in %q\n' "$context" "$expected" "$actual" >&2
        exit 1
    fi
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
    echo "FAIL Center Notch acceptance shell did not become ready" >&2
    exit 1
fi

baseline_center_state="$(call_ipc centerNotch state)"
call_ipc timer start acceptance-satellite-a 120 "Primary acceptance activity" >/dev/null
call_ipc timer start acceptance-satellite-b 180 "Secondary acceptance activity" >/dev/null
require_contains "$(call_ipc centerNotch state)" ";state=satellite" \
    "two ranked activities create Satellite"
activity_state="$(call_ipc center activityState)"
require_contains "$activity_state" '"id":"timer:acceptance-satellite-a"' \
    "Satellite includes its primary test activity"
require_contains "$activity_state" '"id":"timer:acceptance-satellite-b"' \
    "Satellite includes its secondary test activity"
call_ipc timer cancel acceptance-satellite-a >/dev/null
call_ipc timer cancel acceptance-satellite-b >/dev/null
if [[ "$(call_ipc centerNotch state)" != "$baseline_center_state" ]]; then
    echo "FAIL removing test activities did not restore the environment's baseline Center state" >&2
    exit 1
fi

overview_state="$(call_ipc centerNotch open overview)"
require_contains "$overview_state" "open:" "Center Notch open"
require_contains "$overview_state" ";page=overview" "Center Notch Overview"
require_contains "$overview_state" ";state=expanded" "Center expanded state"
require_contains "$(call_ipc centerNotch page banner)" ";page=banner" "Center banner mode"
require_contains "$(call_ipc centerNotch state)" ";state=banner" "Center banner stable state"
require_contains "$(call_ipc centerNotch state)" ";context=" "Center context snapshot"
require_contains "$(call_ipc centerNotch page tools)" ";page=overview" "Center ignores Tools"
require_contains "$(call_ipc centerNotch page monitoring)" ";page=overview" "Monitoring detached"

require_contains "$(call_ipc spotlight toggle)" "open:applications:" "Spotlight mutual exclusion"
require_contains "$(call_ipc centerNotch state)" "closed" "Center Notch closed by Spotlight"
require_contains "$(call_ipc spotlight close)" "closed" "Spotlight close"

require_contains "$(call_ipc centerNotch open overview)" ";page=overview" "Center Notch reopen"
require_contains "$(call_ipc centerNotch close)" "closed" "Center Notch close"
require_contains "$(call_ipc centerNotch state)" "closed" "Center Notch closed state"

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Center Notch acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Center Notch acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="(^|[[:space:]])ERROR([[:space:]:]|$)|\\b(TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Center Notch runtime error found" >&2
    exit 1
fi

echo "PASS Dynamic Island banner/expanded loop, context state, Spotlight exclusion and isolation acceptance"
