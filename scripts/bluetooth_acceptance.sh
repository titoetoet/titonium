#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d --tmpdir titonium-bluetooth-acceptance.XXXXXX)"
log_file="$test_dir/shell.log"
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
    rm -f -- "$log_file"
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

valid_bluetooth_state() {
    printf '%s' "$1" | python3 -c '
import json
import sys
state = json.load(sys.stdin)
required = ("available", "powered", "discovering", "adapterName", "connectedCount", "devices", "stateKey")
if any(key not in state for key in required):
    raise SystemExit(1)
if (not isinstance(state["available"], bool) or not isinstance(state["powered"], bool)
        or not isinstance(state["discovering"], bool) or not isinstance(state["connectedCount"], int)
        or not isinstance(state["devices"], list) or not isinstance(state["stateKey"], str)):
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
    echo "FAIL Bluetooth acceptance shell did not become ready" >&2
    exit 1
fi

bluetooth_state="$(call_ipc bluetooth state)"
if ! valid_bluetooth_state "$bluetooth_state"; then
    printf 'FAIL Bluetooth state has unexpected shape: %q\n' "$bluetooth_state" >&2
    exit 1
fi

popup_state="$(call_ipc bluetooth popup)"
if [[ "$popup_state" != "open:DP-1" ]]; then
    printf 'FAIL Bluetooth popup did not open on DP-1: %q\n' "$popup_state" >&2
    exit 1
fi
if [[ "$(call_ipc bluetooth popupState)" != "$popup_state" ]]; then
    printf 'FAIL Bluetooth popup state changed unexpectedly: %q\n' "$(call_ipc bluetooth popupState)" >&2
    exit 1
fi
if [[ "$(screen_layers DP-1)" != *"titonium-overlay"* ]]; then
    echo "FAIL Bluetooth popup did not own the DP-1 transient layer" >&2
    exit 1
fi
if [[ "$(screen_layers DP-3)" == *"titonium-"* ]]; then
    echo "FAIL DP-3 has a Titonium layer during Bluetooth popup" >&2
    exit 1
fi

if [[ "$(call_ipc spotlight toggle)" != open:applications:DP-1 ]]; then
    printf 'FAIL Spotlight did not replace Bluetooth popup: %q\n' "$(call_ipc spotlight state)" >&2
    exit 1
fi
if [[ "$(call_ipc bluetooth popupState)" != "closed" ]]; then
    printf 'FAIL Spotlight did not close Bluetooth popup: %q\n' "$(call_ipc bluetooth popupState)" >&2
    exit 1
fi
call_ipc spotlight close >/dev/null

if [[ "$(call_ipc bluetooth popup)" != "open:DP-1" ]]; then
    printf 'FAIL Bluetooth popup did not reopen: %q\n' "$(call_ipc bluetooth popupState)" >&2
    exit 1
fi
if [[ "$(call_ipc centerNotch open overview)" != "open:DP-1;page=overview" ]]; then
    printf 'FAIL Center Notch did not replace Bluetooth popup: %q\n' "$(call_ipc centerNotch state)" >&2
    exit 1
fi
if [[ "$(call_ipc bluetooth popupState)" != "closed" ]]; then
    printf 'FAIL Center Notch did not close Bluetooth popup: %q\n' "$(call_ipc bluetooth popupState)" >&2
    exit 1
fi
call_ipc centerNotch close >/dev/null
if [[ "$(call_ipc bluetooth closePopup)" != "closed" || "$(call_ipc bluetooth popupState)" != "closed" ]]; then
    echo "FAIL Bluetooth popup did not close" >&2
    exit 1
fi

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Bluetooth acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Bluetooth acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Bluetooth acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern='\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\b|Type .* unavailable'
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Bluetooth acceptance runtime error found" >&2
    exit 1
fi

echo "PASS Bluetooth read-only state, popup lifecycle and DP-1-only transient acceptance"
