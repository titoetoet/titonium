#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-system-monitor-acceptance.XXXXXX)"
log_file="$test_dir/shell.log"
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
    rm -f -- "$log_file"
    if [[ "$production_was_running" == true ]]; then
        qs -d -p "$project_root" >/dev/null 2>&1 || true
    fi
    rmdir -- "$test_dir"
}
trap cleanup EXIT

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
}

state_is_live() {
    local state
    state="$(call_ipc center monitorState 2>/dev/null || true)"
    python3 -c '
import json, sys
try:
    state = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)
cpu = state.get("snapshot", {}).get("cpu")
ram = state.get("snapshot", {}).get("ram")
storage = state.get("snapshot", {}).get("storage")
valid = (
    state.get("active") is True
    and state.get("live") is True
    and isinstance(state.get("hotSampleAt"), (int, float))
    and isinstance(cpu, dict)
    and isinstance(cpu.get("percent"), (int, float))
    and isinstance(ram, dict)
    and isinstance(ram.get("percent"), (int, float))
    and isinstance(storage, dict)
    and isinstance(storage.get("percent"), (int, float))
)
raise SystemExit(0 if valid else 1)
' "$state"
}

hot_sample_at() {
    call_ipc center monitorState | python3 -c '
import json, sys
print(json.load(sys.stdin).get("hotSampleAt", 0))
'
}

state_is_stopped() {
    local state
    state="$(call_ipc center monitorState 2>/dev/null || true)"
    python3 -c '
import json, sys
try:
    state = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)
valid = (
    state.get("active") is False
    and state.get("live") is False
    and state.get("psRunning") is False
    and state.get("discoveryRunning") is False
    and state.get("gpuInfoRunning") is False
    and state.get("storageRunning") is False
)
raise SystemExit(0 if valid else 1)
' "$state"
}

if qs -p "$project_root" ipc call app status >/dev/null 2>&1; then
    production_was_running=true
    qs -p "$project_root" kill >/dev/null 2>&1 || true
    stopped=false
    for _ in {1..50}; do
        if ! qs -p "$project_root" ipc call app status >/dev/null 2>&1; then
            stopped=true
            break
        fi
        sleep 0.1
    done
    if [[ "$stopped" != true ]]; then
        echo "FAIL production Titonium instance did not stop" >&2
        exit 1
    fi
fi

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
if [[ "$ready" != true ]]; then
    sed -n '1,260p' "$log_file" >&2
    echo "FAIL System Monitor acceptance shell did not become ready" >&2
    exit 1
fi

open_state="$(call_ipc centerNotch open monitoring)"
if [[ "$open_state" != *";page=monitoring"* ]]; then
    printf 'FAIL Monitoring page did not open: %q\n' "$open_state" >&2
    exit 1
fi

live=false
for _ in {1..50}; do
    if state_is_live; then
        live=true
        break
    fi
    sleep 0.1
done
if [[ "$live" != true ]]; then
    call_ipc center monitorState >&2 || true
    sed -n '1,260p' "$log_file" >&2
    echo "FAIL System Monitor did not publish live CPU/RAM values" >&2
    exit 1
fi

first_hot="$(hot_sample_at)"
advanced=false
for _ in {1..20}; do
    sleep 0.1
    next_hot="$(hot_sample_at)"
    if python3 -c 'import sys; raise SystemExit(0 if float(sys.argv[2]) > float(sys.argv[1]) else 1)'             "$first_hot" "$next_hot"; then
        advanced=true
        break
    fi
done
if [[ "$advanced" != true ]]; then
    echo "FAIL hot System Monitor cadence did not advance" >&2
    exit 1
fi

if [[ "$(call_ipc centerNotch page notifications)" != *";page=notifications"* ]]; then
    echo "FAIL could not leave Monitoring page" >&2
    exit 1
fi

stopped=false
for _ in {1..30}; do
    if state_is_stopped; then
        stopped=true
        break
    fi
    sleep 0.1
done
if [[ "$stopped" != true ]]; then
    call_ipc center monitorState >&2 || true
    echo "FAIL System Monitor collectors remained active after leaving page" >&2
    exit 1
fi

if [[ "$(call_ipc centerNotch open monitoring)" != *";page=monitoring"* ]]; then
    echo "FAIL could not reopen Monitoring page" >&2
    exit 1
fi
live=false
for _ in {1..30}; do
    if state_is_live; then
        live=true
        break
    fi
    sleep 0.1
done
if [[ "$live" != true ]]; then
    echo "FAIL System Monitor did not reinitialize with popup" >&2
    exit 1
fi
call_ipc centerNotch close >/dev/null
stopped=false
for _ in {1..10}; do
    if state_is_stopped; then
        stopped=true
        break
    fi
    sleep 0.1
done
if [[ "$stopped" != true ]]; then
    echo "FAIL System Monitor did not release when popup closed" >&2
    exit 1
fi

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL System Monitor acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live"         || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL System Monitor acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,260p' "$log_file" >&2
    echo "FAIL missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,260p' "$log_file" >&2
    echo "FAIL System Monitor runtime error found" >&2
    exit 1
fi

echo "PASS on-demand System Monitor live cadence and stop lifecycle"
