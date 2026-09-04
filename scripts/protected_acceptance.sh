#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_approval_sock="$(mktemp -u --tmpdir titonium-protected-test-approval.XXXXXX.sock)"
focus_test_dir="$(mktemp -d --tmpdir titonium-focus-handoff-acceptance.XXXXXX)"
focus_log_file="$focus_test_dir/shell.log"
focus_shell_pid=""
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_approval_sock"

cleanup() {
    if [[ -n "$focus_shell_pid" ]] && kill -0 "$focus_shell_pid" 2>/dev/null; then
        kill "$focus_shell_pid" 2>/dev/null || true
        wait "$focus_shell_pid" 2>/dev/null || true
    fi
    rm -f -- "$test_approval_sock"
    case "$focus_test_dir" in
        /tmp/titonium-focus-handoff-acceptance.*) rm -rf -- "$focus_test_dir" ;;
    esac
}
trap cleanup EXIT

before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

focus_ipc() {
    qs -p "$project_root" ipc --pid "$focus_shell_pid" call "$@"
}

wait_for_focus_event() {
    local event="$1"
    local context="$2"
    for _ in {1..80}; do
        if rg -Fq "$event" "$focus_log_file"; then
            return 0
        fi
        sleep 0.05
    done
    sed -n '1,260p' "$focus_log_file" >&2
    printf 'FAIL %s: missing focus event %q\n' "$context" "$event" >&2
    return 1
}

require_focus_handoff() {
    local old_owner="$1"
    local new_owner="$2"
    local release_line=""
    local acquire_line=""
    local release_event="released $old_owner"
    local acquire_event="acquired $new_owner"

    wait_for_focus_event "$release_event" "focus handoff release"
    wait_for_focus_event "$acquire_event" "focus handoff acquisition"
    release_line="$(rg -n -F "$release_event" "$focus_log_file" | tail -n 1 | cut -d: -f1)"
    acquire_line="$(rg -n -F "$acquire_event" "$focus_log_file" | tail -n 1 | cut -d: -f1)"
    if [[ -z "$release_line" || -z "$acquire_line" || "$release_line" -ge "$acquire_line" ]]; then
        sed -n '1,260p' "$focus_log_file" >&2
        printf 'FAIL focus handoff order: expected %q before %q\n' \
            "$release_event" "$acquire_event" >&2
        return 1
    fi
}

run_focus_handoff_acceptance() {
    XDG_DATA_HOME="$focus_test_dir/data" \
    XDG_STATE_HOME="$focus_test_dir/state" \
    XDG_CACHE_HOME="$focus_test_dir/cache" \
    TITONIUM_AGENT_APPROVAL_SOCKET="$focus_test_dir/approval.sock" \
        qs -n -v -p "$project_root" --no-color >"$focus_log_file" 2>&1 &
    focus_shell_pid=$!

    local ready=false
    for _ in {1..80}; do
        if [[ "$(focus_ipc app status 2>/dev/null || true)" == "ready" ]]; then
            ready=true
            break
        fi
        sleep 0.1
    done
    if [[ $ready != true ]]; then
        sed -n '1,260p' "$focus_log_file" >&2
        echo "FAIL focus handoff acceptance shell did not become ready" >&2
        return 1
    fi

    if [[ "$(focus_ipc centerNotch open overview)" != "open:DP-1;mode=expanded" ]]; then
        echo "FAIL focus handoff acceptance did not open Center" >&2
        return 1
    fi
    wait_for_focus_event "acquired center:DP-1" "Center acquisition"

    local spotlight_state="$(focus_ipc spotlight toggle)"
    if [[ "$spotlight_state" != open:applications:DP-1* ]]; then
        printf 'FAIL focus handoff acceptance did not open Spotlight: %q\n' \
            "$spotlight_state" >&2
        return 1
    fi
    require_focus_handoff "center:DP-1" "overlay:spotlight:DP-1"

    if [[ "$(focus_ipc settings open general)" != "open:DP-1;page=general" ]]; then
        echo "FAIL focus handoff acceptance did not open Settings" >&2
        return 1
    fi
    require_focus_handoff "overlay:spotlight:DP-1" "settings:DP-1"

    focus_ipc settings cancel >/dev/null
    wait_for_focus_event "released settings:DP-1" "Settings release"

    if rg -q 'exclusive-focus-conflict|missing-focus-owner' "$focus_log_file"; then
        rg -n 'exclusive-focus-conflict|missing-focus-owner' "$focus_log_file" >&2
        echo "FAIL focus handoff acceptance found a rejected diagnostic" >&2
        return 1
    fi
    if ! rg -q 'Configuration Loaded' "$focus_log_file"; then
        sed -n '1,260p' "$focus_log_file" >&2
        echo "FAIL focus handoff acceptance missing Configuration Loaded" >&2
        return 1
    fi
    rg -n '\[titonium\]\[focus\] (released|acquired)' "$focus_log_file"
    echo "PASS exclusive focus handoffs release before acquisition"
}

if rg -n 'Process\s*\{|Timer\s*\{' \
    "$project_root/Titonium/Bar/widgets/InputMethod.qml" \
    "$project_root/Titonium/Services/InputMethod/InputMethodService.qml"; then
    echo "FAIL Input Method owns a Process or Timer" >&2
    exit 1
fi

"$project_root/scripts/spotlight_acceptance.sh"
"$project_root/scripts/dock_acceptance.sh"
"$project_root/scripts/bluetooth_acceptance.sh"
"$project_root/scripts/wifi_acceptance.sh"
"$project_root/scripts/window_switcher_acceptance.sh"
"$project_root/scripts/workspace_interactions_acceptance.sh"
"$project_root/scripts/notifications_acceptance.sh"
"$project_root/scripts/center_attention_acceptance.sh"
"$project_root/scripts/settings_acceptance.sh"
run_focus_handoff_acceptance

after_live="$(sha256sum -- "$live_hypr")"
after_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

if [[ "$after_live" != "$before_live" || "$after_dotfiles" != "$before_dotfiles" ]]; then
    echo "FAIL protected acceptance changed a Hyprland configuration" >&2
    exit 1
fi

echo "PASS protected Spotlight, Input Method, Dock, Bluetooth, Wi-Fi, Window Switcher, workspace, notification, Center attention, Settings and exclusive focus handoff acceptance"
