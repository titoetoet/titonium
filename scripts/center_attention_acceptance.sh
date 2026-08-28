#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-center-attention-acceptance.XXXXXX)"
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
        /tmp/titonium-center-attention-acceptance.*) rm -rf -- "$test_dir" ;;
    esac
}
trap cleanup EXIT

call_ipc() {
    qs -p "$project_root" ipc --pid "$shell_pid" call "$@"
}

screen_layers() {
    local screen_name="$1"
    hyprctl -j layers | python3 -c '
import json, sys
print(json.dumps(json.load(sys.stdin).get(sys.argv[1], {}), sort_keys=True))
' "$screen_name"
}

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
    echo "FAIL Center attention acceptance shell did not become ready" >&2
    exit 1
fi

center_state="$(call_ipc center state)"
printf '%s' "$center_state" | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("transient") is not False: raise SystemExit(1)
if state.get("current") is not None: raise SystemExit(1)
if state.get("pendingCount") != 0: raise SystemExit(1)
if not isinstance(state.get("indicators"), list): raise SystemExit(1)
'

focus_state=""
focus_ready=false
for _ in {1..30}; do
    focus_state="$(call_ipc center focusState)"
    if printf '%s' "$focus_state" | python3 -c '
import json, sys
raise SystemExit(0 if json.load(sys.stdin).get("ready") is True else 1)
'; then
        focus_ready=true
        break
    fi
    sleep 0.1
done
if [[ $focus_ready != true ]]; then
    printf 'FAIL Center focus store did not become ready: %q\n' "$focus_state" >&2
    exit 1
fi
printf '%s' "$focus_state" | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("text") not in ("Focus for today", "Tập trung cho hôm nay"):
    raise SystemExit(1)
if state.get("launching") is not False: raise SystemExit(1)
if not state.get("focusPath", "").endswith("/center/daily-focus.md"):
    raise SystemExit(1)
if not state.get("promptsPath", "").endswith("/center/focus-prompts.txt"):
    raise SystemExit(1)
'

dp1_layers="$(screen_layers DP-1)"
dp3_layers="$(screen_layers DP-3)"
dp1_bar_count="$(printf '%s' "$dp1_layers" | rg -o 'titonium-menubar' | wc -l)"
if [[ "$dp1_bar_count" -ne 1 ]]; then
    printf 'FAIL expected one DP-1 Titonium Bar, found %s in %q\n' "$dp1_bar_count" "$dp1_layers" >&2
    exit 1
fi
if [[ "$dp3_layers" == *"titonium-"* ]]; then
    echo "FAIL Center attention acceptance found a Titonium DP-3 layer" >&2
    exit 1
fi

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Center attention acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Center attention acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Center attention acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Center attention runtime error found" >&2
    exit 1
fi

echo "PASS Center read-only state, Daily Focus fallback and DP-1-only Bar acceptance"
