#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-settings-acceptance.XXXXXX)"
runtime_dir="$test_dir/data/titonium"
log_file="$test_dir/shell.log"
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
        /tmp/titonium-settings-acceptance.*) rm -rf -- "$test_dir" ;;
    esac
}
trap cleanup EXIT

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
}

require_equal() {
    local actual="$1"
    local expected="$2"
    local context="$3"
    if [[ "$actual" != "$expected" ]]; then
        printf 'FAIL %s: expected %q, got %q\n' "$context" "$expected" "$actual" >&2
        exit 1
    fi
}

screen_layers() {
    local screen_name="$1"
    hyprctl -j layers | python3 -c '
import json, sys
print(json.dumps(json.load(sys.stdin).get(sys.argv[1], {}), sort_keys=True))
' "$screen_name"
}

mkdir -p -- "$runtime_dir" "$test_dir/state" "$test_dir/cache"
cp -- "$project_root/tests/fixtures/settings-v6-runtime.json" "$runtime_dir/settings.json"
cp -- "$project_root/tests/fixtures/dock-v1-runtime.json" "$runtime_dir/dock.json"

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
    echo "FAIL Settings acceptance shell did not become ready" >&2
    exit 1
fi

require_equal "$(call_ipc settings open general)" \
    "open:DP-1;page=general" "Settings open General"
require_equal "$(call_ipc settings state)" \
    "open:DP-1;page=general;dirty=false;saving=false" "Settings General state"

dp1_layers="$(screen_layers DP-1)"
dp3_layers="$(screen_layers DP-3)"
dp1_settings_count="$(printf '%s' "$dp1_layers" | rg -o 'titonium-settings' | wc -l)"
if [[ "$dp1_settings_count" -ne 1 ]]; then
    printf 'FAIL expected one DP-1 Settings layer, found %s in %q\n' \
        "$dp1_settings_count" "$dp1_layers" >&2
    exit 1
fi
if [[ "$dp3_layers" == *"titonium-"* ]]; then
    printf 'FAIL Settings acceptance found a Titonium DP-3 layer: %q\n' "$dp3_layers" >&2
    exit 1
fi

require_equal "$(call_ipc settings page dock)" \
    "open:DP-1;page=dock;dirty=false;saving=false" "Settings Dock page"

spotlight_state="$(call_ipc spotlight toggle)"
if [[ "$spotlight_state" != open:applications:DP-1* ]]; then
    printf 'FAIL Spotlight did not open on DP-1: %q\n' "$spotlight_state" >&2
    exit 1
fi
require_equal "$(call_ipc settings state)" "closed" \
    "Spotlight closes Settings and cancels preview"

require_equal "$(call_ipc centerNotch open overview)" \
    "open:DP-1;page=overview" "Center Notch open"
require_equal "$(call_ipc spotlight state)" "closed" "Center Notch closes Spotlight"

require_equal "$(call_ipc settings open dock)" \
    "open:DP-1;page=dock" "Settings reopens on Dock"
require_equal "$(call_ipc centerNotch state)" "closed" "Settings closes Center Notch"
require_equal "$(call_ipc settings cancel)" "closed" "Settings cancel"
require_equal "$(call_ipc settings state)" "closed" "Settings closed state"

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Settings acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Settings acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Settings acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Settings acceptance runtime error found" >&2
    exit 1
fi

echo "PASS Settings v6 migration, lifecycle exclusivity and DP-1-only layer acceptance"
