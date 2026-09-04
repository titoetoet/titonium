#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_approval_sock="$(mktemp -u --tmpdir titonium-protected-test-approval.XXXXXX.sock)"
focus_test_dir="$(mktemp -d --tmpdir titonium-focus-handoff-acceptance.XXXXXX)"
focus_log_file="$focus_test_dir/shell.log"
focus_shell_pid=""
focus_trace_checker="$project_root/scripts/check_focus_handoff_trace.py"
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

focus_log_cursor() {
    wc -l < "$focus_log_file" | tr -d '[:space:]'
}

wait_for_focus_trace() {
    local context="$1"
    shift
    local result=""
    local status=0
    for _ in {1..80}; do
        if result="$(python3 "$focus_trace_checker" "$@" 2>&1)"; then
            return 0
        else
            status=$?
        fi
        if [[ $status -ne 2 ]]; then
            printf 'FAIL %s: %s\n' "$context" "$result" >&2
            return 1
        fi
        sleep 0.05
    done
    sed -n '1,260p' "$focus_log_file" >&2
    printf 'FAIL %s: %s\n' "$context" "$result" >&2
    return 1
}

require_focus_handoff() {
    local old_owner="$1"
    local new_owner="$2"
    local cursor="$3"
    wait_for_focus_trace "focus handoff $old_owner to $new_owner" handoff \
        "$focus_log_file" "$cursor" "$old_owner" "$new_owner"
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

    local center_cursor="$(focus_log_cursor)"
    if [[ "$(focus_ipc centerNotch open overview)" != "open:DP-1;mode=expanded" ]]; then
        echo "FAIL focus handoff acceptance did not open Center" >&2
        return 1
    fi
    wait_for_focus_trace "Center acquisition" event "$focus_log_file" "$center_cursor" \
        acquired "center:DP-1"

    local spotlight_cursor="$(focus_log_cursor)"
    local spotlight_state="$(focus_ipc spotlight toggle)"
    if [[ "$spotlight_state" != open:applications:DP-1* ]]; then
        printf 'FAIL focus handoff acceptance did not open Spotlight: %q\n' \
            "$spotlight_state" >&2
        return 1
    fi
    require_focus_handoff "center:DP-1" "overlay:spotlight:DP-1" "$spotlight_cursor"

    local settings_cursor="$(focus_log_cursor)"
    if [[ "$(focus_ipc settings open general)" != "open:DP-1;page=general" ]]; then
        echo "FAIL focus handoff acceptance did not open Settings" >&2
        return 1
    fi
    require_focus_handoff "overlay:spotlight:DP-1" "settings:DP-1" "$settings_cursor"

    local settings_close_cursor="$(focus_log_cursor)"
    focus_ipc settings cancel >/dev/null
    wait_for_focus_trace "Settings release" event "$focus_log_file" "$settings_close_cursor" \
        released "settings:DP-1"

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
