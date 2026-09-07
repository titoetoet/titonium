#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
log_file="$(mktemp --tmpdir titonium-smoke.XXXXXX.log)"
test_approval_sock="$(mktemp -u --tmpdir titonium-smoke-approval.XXXXXX.sock)"
export TITONIUM_AGENT_APPROVAL_SOCKET="${TITONIUM_AGENT_APPROVAL_SOCKET:-$test_approval_sock}"
trap 'rm -f -- "$log_file" "$test_approval_sock"' EXIT

set +e
timeout --signal=TERM 8s qs -n -p "$project_root" >"$log_file" 2>&1
status=$?
set -e

if [[ $status -ne 0 && $status -ne 124 ]]; then
    sed -n '1,240p' "$log_file" >&2
    exit "$status"
fi

if ! rg -q 'Configuration Loaded' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL missing Configuration Loaded" >&2
    exit 1
fi

if rg -i '\b(ERROR|TypeError|duplicate id|missing method|Illegal method name)\b|Type .* unavailable|Binding loop detected' "$log_file"; then
    sed -n '1,240p' "$log_file" >&2
    echo "FAIL runtime error found" >&2
    exit 1
fi

echo "PASS foreground smoke"
