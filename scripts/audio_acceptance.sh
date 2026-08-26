#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d --tmpdir titonium-audio-acceptance.XXXXXX)"
log_file="$test_dir/shell.log"
shell_pid=""

before_git="$(git -C "$project_root" status --porcelain=v1)"

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
state_pattern='^ready=(true|false);output=(true|false);volume=[0-9]+;muted=(true|false);input=(true|false);streams=[0-9]+$'
if [[ ! "$audio_state" =~ $state_pattern ]]; then
    printf 'FAIL audio state has unexpected shape: %q\n' "$audio_state" >&2
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
if [[ "$(call_ipc audio popupState)" != "$popup_state" ]]; then
    printf 'FAIL audio popup state changed unexpectedly: %q\n' "$(call_ipc audio popupState)" >&2
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
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL audio acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern='\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\b|Type .* unavailable'
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL audio acceptance runtime error found" >&2
    exit 1
fi

echo "PASS audio read-only OSD state and popup acceptance"
