#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-center-activity-acceptance.XXXXXX)"
runtime_root="$test_dir/runtime"
log_file="$test_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_dir/approval.sock"
shell_pid=""
normal_id="acceptance:activity:normal"
important_id="acceptance:activity:important"
probe_id="acceptance:activity:probe"
timer_id="acceptance:activity:timer"

before_git="$(git -C "$project_root" status --porcelain=v1)"
before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

mkdir -p -- "$runtime_root"
cp -a -- \
    "$project_root/Titonium" \
    "$project_root/config" \
    "$project_root/shell.qml" \
    "$runtime_root/"

call_ipc() {
    qs -p "$runtime_root" ipc --pid "$shell_pid" call "$@"
}

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        call_ipc job clear "$normal_id" >/dev/null 2>&1 || true
        call_ipc job clear "$important_id" >/dev/null 2>&1 || true
        call_ipc job clear "$probe_id" >/dev/null 2>&1 || true
        call_ipc timer cancel "$timer_id" >/dev/null 2>&1 || true
        call_ipc centerNotch close >/dev/null 2>&1 || true
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    case "$test_dir" in
        /tmp/titonium-center-activity-acceptance.*) rm -rf -- "$test_dir" ;;
    esac
}
trap cleanup EXIT

activity_matches() {
    local state="$1"
    local expected="$2"
    printf '%s' "$state" | python3 -c '
import json, sys
state = json.load(sys.stdin)
expected = sys.argv[1]
if expected == "focus":
    ok = state.get("showingFocus") is True and not state.get("currentId")
else:
    ok = state.get("showingFocus") is False and state.get("currentId") == expected
raise SystemExit(0 if ok else 1)
' "$expected"
}

wait_for_activity() {
    local expected="$1"
    local attempts="$2"
    local state=""
    for ((attempt = 0; attempt < attempts; attempt++)); do
        state="$(call_ipc center activityState)"
        if activity_matches "$state" "$expected"; then
            printf '%s' "$state"
            return 0
        fi
        sleep 0.25
    done
    printf 'FAIL Activity slot %q was not observed; last=%q\n' "$expected" "$state" >&2
    return 1
}

wait_for_attention_clear() {
    local state=""
    for _ in {1..32}; do
        state="$(call_ipc center state)"
        if printf '%s' "$state" | python3 -c '
import json, sys
raise SystemExit(0 if json.load(sys.stdin).get("current") is None else 1)
'; then
            return 0
        fi
        sleep 0.25
    done
    printf 'FAIL Center Attention did not clear; last=%q\n' "$state" >&2
    return 1
}

menubar_count() {
    hyprctl -j layers | rg -o 'titonium-menubar' | wc -l
}

XDG_DATA_HOME="$test_dir/data" \
XDG_STATE_HOME="$test_dir/state" \
XDG_CACHE_HOME="$test_dir/cache" \
    qs -n -p "$runtime_root" --no-color >"$log_file" 2>&1 &
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
    echo "FAIL Center Activity acceptance shell did not become ready" >&2
    exit 1
fi

initial_activity="$(call_ipc center activityState)"
printf '%s' "$initial_activity" | python3 -c '
import json, sys
state = json.load(sys.stdin)
activities = state.get("activities", [])
if any(item.get("source") != "media" for item in activities):
    raise SystemExit(1)
if activities:
    if state.get("showingFocus") is not False or state.get("currentId") != "media:current":
        raise SystemExit(1)
    if state.get("presentation") is None or state.get("scheduledAt", 0) <= 0:
        raise SystemExit(1)
elif state.get("showingFocus") is not True or state.get("presentation") is not None \
        or state.get("scheduledAt") != 0:
    raise SystemExit(1)
'
baseline_bars="$(menubar_count)"

[[ "$(call_ipc job start "$normal_id" "Normal build" normal)" == "ok" ]]
[[ "$(call_ipc job start "$important_id" "Important build" important)" == "ok" ]]
call_ipc timer start "$timer_id" 120 "Tea timer" >/dev/null
[[ "$(call_ipc job progress "$normal_id" 31 Linking)" == "ok" ]]
[[ "$(call_ipc job progress "$normal_id" 62 Compiling)" == "ok" ]]

active_state="$(wait_for_activity "timer:$timer_id" 8)"
printf '%s' "$active_state" | python3 -c '
import json, sys
state = json.load(sys.stdin)
activities = state.get("activities", [])
normal = [item for item in activities if item.get("id") == "job:acceptance:activity:normal"]
fixture_ids = {
    "timer:acceptance:activity:timer",
    "job:acceptance:activity:important",
    "job:acceptance:activity:normal",
}
if {item.get("id") for item in activities if item.get("id") in fixture_ids} != fixture_ids \
        or len(normal) != 1:
    raise SystemExit(1)
if normal[0].get("label") != "Compiling" or normal[0].get("progress") != 62:
    raise SystemExit(1)
'

timer_activity_id="timer:$timer_id"
important_activity_id="job:$important_id"
normal_activity_id="job:$normal_id"
wait_for_attention_clear
timer_state="$(wait_for_activity "$timer_activity_id" 88)"
printf '%s' "$timer_state" | python3 -c '
import json, sys, time
state = json.load(sys.stdin)
presentation = state.get("presentation") or {}
if presentation.get("id") != sys.argv[1] or state.get("scheduledAt", 0) <= time.time() * 1000:
    raise SystemExit(1)
' "$timer_activity_id"

[[ "$(call_ipc job start "$probe_id" "Probe completion" normal)" == "ok" ]]
[[ "$(call_ipc job complete "$probe_id" "Probe complete")" == "ok" ]]
printf '%s\n%s' "$(call_ipc center state)" "$(call_ipc center activityState)" | python3 -c '
import json, sys
center = json.loads(sys.stdin.readline())
activity = json.loads(sys.stdin.readline())
current = center.get("current") or {}
if current.get("kind") != "job_completed":
    raise SystemExit(1)
if activity.get("currentId") != sys.argv[1] or activity.get("suspended") is not True:
    raise SystemExit(1)
if activity.get("scheduledAt") != 0:
    raise SystemExit(1)
' "$timer_activity_id"

wait_for_attention_clear
resumed_timer="$(call_ipc center activityState)"
printf '%s' "$resumed_timer" | python3 -c '
import json, sys, time
state = json.load(sys.stdin)
if state.get("currentId") != sys.argv[1] or state.get("suspended") is not False:
    raise SystemExit(1)
remaining = state.get("scheduledAt", 0) - time.time() * 1000
if remaining < 7000 or remaining > 8500:
    raise SystemExit(1)
' "$timer_activity_id"
sleep 1
wait_for_activity "$timer_activity_id" 2 >/dev/null

wait_for_activity "$important_activity_id" 28 >/dev/null
normal_state="$(wait_for_activity "$normal_activity_id" 28)"
printf '%s' "$normal_state" | python3 -c '
import json, sys
state = json.load(sys.stdin)
presentation = state.get("presentation") or {}
if presentation.get("id") != sys.argv[1] or presentation.get("progress") != 62:
    raise SystemExit(1)
' "$normal_activity_id"
wait_for_activity "$timer_activity_id" 28 >/dev/null

if [[ "$(menubar_count)" -ne "$baseline_bars" ]]; then
    echo "FAIL Activity rotation created an extra Bar layer" >&2
    exit 1
fi

call_ipc timer cancel "$timer_id" >/dev/null
[[ "$(call_ipc job complete "$important_id" "Important complete")" == "ok" ]]
[[ "$(call_ipc job complete "$normal_id" "Normal complete")" == "ok" ]]
wait_for_attention_clear
final_activity="$(call_ipc center activityState)"
printf '%s\n%s' "$initial_activity" "$final_activity" | python3 -c '
import json, sys
initial = json.loads(sys.stdin.readline())
state = json.loads(sys.stdin.readline())
baseline = [(item.get("id"), item.get("source")) for item in initial.get("activities", [])]
remaining = [(item.get("id"), item.get("source")) for item in state.get("activities", [])]
if remaining != baseline:
    raise SystemExit(1)
if baseline:
    if state.get("showingFocus") is not False or state.get("currentId") != baseline[0][0]:
        raise SystemExit(1)
    if state.get("presentation") is None or state.get("scheduledAt", 0) <= 0:
        raise SystemExit(1)
elif state.get("showingFocus") is not True or state.get("presentation") is not None \
        or state.get("scheduledAt") != 0:
    raise SystemExit(1)
'

notch_open="$(call_ipc centerNotch open overview)"
if [[ "$notch_open" != open:*";page=overview" ]]; then
    printf 'FAIL Center Notch did not open: %q\n' "$notch_open" >&2
    exit 1
fi
if [[ "$(call_ipc centerNotch close)" != "closed" ]]; then
    echo "FAIL Center Notch did not close" >&2
    exit 1
fi

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Center Activity acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Center Activity acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Center Activity acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Center Activity runtime error found" >&2
    exit 1
fi

echo "PASS Center Activity rotation, preemption, progress and cleanup acceptance"
