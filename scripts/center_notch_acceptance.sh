#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-center-surface-acceptance.XXXXXX)"
log_file="$test_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_dir/approval.sock"
shell_pid=""

before_git="$(git -C "$project_root" status --porcelain=v1)"
before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

if ! rg -q 'CenterSurfaceHost \{' "$project_root/Titonium/Bar/BarHost.qml" \
        || ! rg -q 'WlrLayershell\.namespace: "titonium-center-compact"' \
            "$project_root/Titonium/Core/Surfaces/Center/CenterCompactWindow.qml" \
        || ! rg -q 'WlrLayershell\.namespace: "titonium-center-overlay"' \
            "$project_root/Titonium/Core/Surfaces/Center/CenterOverlayWindow.qml"; then
    echo "FAIL logical Center does not have the neutral host and native roles" >&2
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
    echo "FAIL Center surface acceptance shell did not become ready" >&2
    exit 1
fi

overview_state="$(call_ipc centerNotch open overview)"
require_contains "$overview_state" "open:" "Center open"
require_contains "$overview_state" ";mode=expanded" "Center expanded mode"
require_contains "$(call_ipc centerNotch page banner)" ";mode=banner" "Center banner mode"
require_contains "$(call_ipc centerNotch page overview)" ";mode=expanded" "Center expanded restore"

require_contains "$(call_ipc spotlight toggle)" "open:applications:" "Spotlight mutual exclusion"
require_contains "$(call_ipc centerNotch state)" "closed" "Center closed by Spotlight"
require_contains "$(call_ipc spotlight close)" "closed" "Spotlight close"

require_contains "$(call_ipc centerNotch open overview)" ";mode=expanded" "Center reopen"
require_contains "$(call_ipc centerNotch close)" "closed" "Center close"
require_contains "$(call_ipc centerNotch state)" "closed" "Center closed state"

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Center acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Center acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Center runtime error found" >&2
    exit 1
fi

echo "PASS neutral Center modes, Spotlight exclusion and isolation acceptance"
