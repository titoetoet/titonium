#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
live_hypr="/home/cole/.config/hypr/hyprland.lua"
dotfiles_hypr="/home/cole/Projects/titonium-hyprland/config/hypr/hyprland.lua"
test_dir="$(mktemp -d --tmpdir titonium-center-job-acceptance.XXXXXX)"
runtime_root="$test_dir/runtime"
log_file="$test_dir/shell.log"
export TITONIUM_AGENT_APPROVAL_SOCKET="$test_dir/approval.sock"
shell_pid=""

before_git="$(git -C "$project_root" status --porcelain=v1)"
before_live="$(sha256sum -- "$live_hypr")"
before_dotfiles="$(sha256sum -- "$dotfiles_hypr")"

mkdir -p -- "$runtime_root"
cp -a -- \
    "$project_root/Titonium" \
    "$project_root/config" \
    "$project_root/shell.qml" \
    "$runtime_root/"

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    case "$test_dir" in
        /tmp/titonium-center-job-acceptance.*) rm -rf -- "$test_dir" ;;
    esac
}
trap cleanup EXIT

call_ipc() {
    qs -p "$runtime_root" ipc --pid "$shell_pid" call "$@"
}

wait_for_notification_queue() {
    local expected_count="$1"
    local expected_key="$2"
    local state=""
    for _ in {1..40}; do
        state="$(call_ipc notifications state 2>/dev/null || true)"
        if python3 -c '
import json, sys
try:
    state = json.loads(sys.argv[1])
except Exception:
    raise SystemExit(1)
queue = state.get("queue") or {}
raise SystemExit(0 if queue.get("count") == int(sys.argv[2])
    and queue.get("currentKey") in ("", sys.argv[3]) else 1)
' "$state" "$expected_count" "$expected_key"; then
            return 0
        fi
        sleep 0.1
    done
    printf 'FAIL Notification queue mismatch: expected=%s:%q state=%q\n' \
        "$expected_count" "$expected_key" "$state" >&2
    return 1
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
    echo "FAIL Job acceptance shell did not become ready" >&2
    exit 1
fi

call_ipc job state | python3 -c '
import json, sys
state = json.load(sys.stdin)
if state.get("activeCount") != 0 or state.get("jobs") != []:
    raise SystemExit(1)
'
if [[ "$(call_ipc job progress missing 10 Work)" != "error:not_found" ]]; then
    echo "FAIL unknown Job progress did not fail closed" >&2
    exit 1
fi
if [[ "$(call_ipc job progress missing nope Work)" != "error:invalid" ]]; then
    echo "FAIL malformed Job percentage did not return a stable error" >&2
    exit 1
fi
if [[ "$(call_ipc job start bad Bad urgent)" != "error:invalid" ]]; then
    echo "FAIL invalid Job importance did not fail closed" >&2
    exit 1
fi

if [[ "$(call_ipc job start build "Build Titonium" important)" != "ok" ]]; then
    echo "FAIL important Job did not start" >&2
    exit 1
fi
before_progress="$(call_ipc center state)"
if [[ "$(call_ipc job progress build 50 Compiling)" != "ok" ]]; then
    echo "FAIL Job progress was rejected" >&2
    exit 1
fi
after_progress="$(call_ipc center state)"
printf '%s\n%s' "$before_progress" "$after_progress" | python3 -c '
import json, sys
before = json.loads(sys.stdin.readline())
after = json.loads(sys.stdin.readline())
current = before.get("current") or {}
if current.get("kind") != "job_started" or current.get("priority") != 20:
    raise SystemExit(1)
if after.get("current") != before.get("current"):
    raise SystemExit(1)
if not any(item.get("id") == "jobs" for item in after.get("indicators", [])):
    raise SystemExit(1)
'
if [[ "$(call_ipc job complete build "Build complete")" != "ok" ]]; then
    echo "FAIL Job completion was rejected" >&2
    exit 1
fi
printf '%s\n%s' "$(call_ipc job state)" "$(call_ipc center state)" | python3 -c '
import json, sys
jobs = json.loads(sys.stdin.readline())
center = json.loads(sys.stdin.readline())
current = center.get("current") or {}
if jobs.get("activeCount") != 0:
    raise SystemExit(1)
if current.get("kind") != "job_completed" or current.get("priority") != 50:
    raise SystemExit(1)
if any(item.get("id") == "jobs" for item in center.get("indicators", [])):
    raise SystemExit(1)
'
if [[ "$(call_ipc job clear build)" != "ok" ]]; then
    echo "FAIL terminal Job event could not be cleared" >&2
    exit 1
fi
call_ipc centerNotch close >/dev/null

call_ipc job start download Download normal >/dev/null
call_ipc job fail download "Download failed" >/dev/null
wait_for_notification_queue 1 "internal:job_failed:download"
call_ipc job clear download >/dev/null
wait_for_notification_queue 0 ""

call_ipc job start deploy Deploy important >/dev/null
call_ipc job requireAction deploy "Approve deployment" >/dev/null
wait_for_notification_queue 1 "internal:job_requires_action:deploy"
printf '%s\n%s' "$(call_ipc job state)" "$(call_ipc notifications state)" | python3 -c '
import json, sys
jobs = json.loads(sys.stdin.readline())
notifications = json.loads(sys.stdin.readline())
queue = notifications.get("queue") or {}
if jobs.get("activeCount") != 1 or jobs["jobs"][0].get("status") != "requires_action":
    raise SystemExit(1)
if queue.get("count") != 1 or queue.get("currentKey") not in (
        "", "internal:job_requires_action:deploy"):
    raise SystemExit(1)
'
call_ipc job clear deploy >/dev/null
printf '%s\n%s\n%s' "$(call_ipc job state)" "$(call_ipc notifications state)" \
    "$(call_ipc center state)" | python3 -c '
import json, sys
jobs = json.loads(sys.stdin.readline())
notifications = json.loads(sys.stdin.readline())
center = json.loads(sys.stdin.readline())
queue = notifications.get("queue") or {}
if jobs.get("activeCount") != 0 or queue.get("count") != 0 \
        or queue.get("currentKey") != "":
    raise SystemExit(1)
if any(item.get("id") == "jobs" for item in center.get("indicators", [])):
    raise SystemExit(1)
'

if [[ "$(git -C "$project_root" status --porcelain=v1)" != "$before_git" ]]; then
    git -C "$project_root" status --short >&2
    echo "FAIL Job acceptance changed repository files" >&2
    exit 1
fi
if [[ "$(sha256sum -- "$live_hypr")" != "$before_live" \
        || "$(sha256sum -- "$dotfiles_hypr")" != "$before_dotfiles" ]]; then
    echo "FAIL Job acceptance changed a Hyprland configuration" >&2
    exit 1
fi
if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Job acceptance missing Configuration Loaded" >&2
    exit 1
fi
runtime_rejection_pattern="\\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\\b|Type .* unavailable"
if rg -i "$runtime_rejection_pattern" "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL Job runtime error found" >&2
    exit 1
fi

echo "PASS Center Job IPC, priorities, progress silence and exact clear acceptance"
