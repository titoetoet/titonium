#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
log_file="$(mktemp --tmpdir titonium-spotlight-acceptance.XXXXXX.log)"
shell_pid=""

cleanup() {
    if [[ -n "$shell_pid" ]] && kill -0 "$shell_pid" 2>/dev/null; then
        kill "$shell_pid" 2>/dev/null || true
        wait "$shell_pid" 2>/dev/null || true
    fi
    rm -f -- "$log_file"
}
trap cleanup EXIT

call_ipc() {
    qs -p "$project_root" ipc --newest call "$@"
}

require_contains() {
    local actual="$1"
    local expected="$2"
    local context="$3"
    if [[ "$actual" != *"$expected"* ]]; then
        printf 'FAIL %s: expected %q in %q\n' "$context" "$expected" "$actual" >&2
        exit 1
    fi
}

qs -p "$project_root" --no-color >"$log_file" 2>&1 &
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
    echo "FAIL Spotlight acceptance shell did not become ready" >&2
    exit 1
fi

open_state="$(call_ipc spotlight toggle)"
require_contains "$open_state" "open:applications:" "Spotlight toggle"
require_contains "$(call_ipc spotlight state)" "open:applications:" "Spotlight open state"

call_ipc spotlight setQuery fire >/dev/null
results_state="$(call_ipc spotlight state)"
require_contains "$results_state" "mode=results;query=fire;selected=0" "Spotlight search state"

require_contains "$(call_ipc spotlight close)" "closed" "Spotlight close"
require_contains "$(call_ipc spotlight state)" "closed" "Spotlight closed state"

if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL missing Configuration Loaded" >&2
    exit 1
fi
if rg -i '\b(ERROR|TypeError|duplicate id|missing method)\b' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL runtime error found" >&2
    exit 1
fi

echo "PASS Spotlight IPC toggle, search state and close acceptance"
