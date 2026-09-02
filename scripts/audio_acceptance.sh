#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-audio-acceptance.XXXXXX)"
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
    rm -f -- "$log_file" "$test_dir/approval.sock"
    rmdir -- "$test_dir"
}
trap cleanup EXIT

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
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
    echo "FAIL audio acceptance shell did not become ready" >&2
    exit 1
fi

audio_state="$(call_ipc audio state)"
state_pattern='^ready=(true|false);output=(true|false);volume=[0-9]+;muted=(true|false);input=(true|false);outputs=[0-9]+;streams=[0-9]+$'
if [[ ! "$audio_state" =~ $state_pattern ]]; then
    printf 'FAIL audio state has unexpected shape: %q\n' "$audio_state" >&2
    exit 1
fi
if [[ "$audio_state" == *"output=true"* && "$audio_state" == *"outputs=0"* ]]; then
    printf 'FAIL audio state lost ready output devices: %q\n' "$audio_state" >&2
    exit 1
fi

if [[ "$(call_ipc audio osdState)" != "idle" ]]; then
    printf 'FAIL audio OSD was not idle at startup: %q\n' "$(call_ipc audio osdState)" >&2
    exit 1
fi

popup_state="$(call_ipc audio popup)"
if [[ ! "$popup_state" =~ ^open:[^[:space:]]+$ ]]; then
    printf 'FAIL audio popup did not open: %q\n' "$popup_state" >&2
    exit 1
fi
popup_screen="${popup_state#open:}"
if [[ "$(call_ipc audio popupState)" != "$popup_state" ]]; then
    printf 'FAIL audio popup state changed unexpectedly: %q\n' "$(call_ipc audio popupState)" >&2
    exit 1
fi

center_notch_state="$(call_ipc centerNotch open overview)"
if [[ "$center_notch_state" != "open:${popup_screen};page=overview" ]]; then
    printf 'FAIL Center Notch screen/page mismatch: expected %q, got %q\n' \
        "open:${popup_screen};page=overview" "$center_notch_state" >&2
    exit 1
fi
if [[ "$(call_ipc audio popupState)" != "closed" ]]; then
    printf 'FAIL Center Notch did not close Audio popup: %q\n' "$(call_ipc audio popupState)" >&2
    exit 1
fi
if [[ "$(call_ipc centerNotch close)" != "closed" ]]; then
    echo "FAIL Center Notch did not close" >&2
    exit 1
fi

popup_state="$(call_ipc audio popup)"
if [[ ! "$popup_state" =~ ^open:[^[:space:]]+$ ]]; then
    printf 'FAIL audio popup did not reopen: %q\n' "$popup_state" >&2
    exit 1
fi
if [[ "$(call_ipc spotlight toggle)" != open:applications:* ]]; then
    printf 'FAIL Spotlight did not open: %q\n' "$(call_ipc spotlight state)" >&2
    exit 1
fi
if [[ "$(call_ipc audio popupState)" != "closed" ]]; then
    printf 'FAIL Spotlight did not close Audio popup: %q\n' "$(call_ipc audio popupState)" >&2
    exit 1
fi
if [[ "$(call_ipc spotlight close)" != "closed" ]]; then
    echo "FAIL Spotlight did not close" >&2
    exit 1
fi
if [[ "$(call_ipc audio closePopup)" != "closed" ]]; then
    echo "FAIL audio popup did not close" >&2
    exit 1
fi
if [[ "$(call_ipc audio popupState)" != "closed" ]]; then
    printf 'FAIL audio popup state was not closed: %q\n' "$(call_ipc audio popupState)" >&2
    exit 1
fi
if [[ "$(call_ipc audio osdState)" != "idle" ]]; then
    printf 'FAIL audio OSD was not idle after popup lifecycle: %q\n' "$(call_ipc audio osdState)" >&2
    exit 1
fi

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL audio acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL audio acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL audio acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern='ERROR|TypeError|Illegal method name|Type .* unavailable|duplicate id|missing method'
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL audio acceptance runtime error found" >&2
    exit 1
fi

echo "PASS audio read-only popup, Center Notch and Spotlight acceptance"
